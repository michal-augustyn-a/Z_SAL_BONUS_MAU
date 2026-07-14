CLASS zcl_sal_bonus_db_mau DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS constructor .
    METHODS save_calculated_bonuses
      IMPORTING
        !it_bonus_data    TYPE ztt_sal_bonus_mau
        !it_target_data   TYPE ztt_sal_targets_mau
      EXPORTING
        !ev_message       TYPE string
      RETURNING
        VALUE(rv_success) TYPE abap_bool .
    METHODS get_active_employees
      IMPORTING
        !iv_gjahr       TYPE gjahr
        !iv_quarter     TYPE z_sal_quarter_e_mau
        !iv_begda       TYPE datum
        !iv_endda       TYPE datum
      RETURNING
        VALUE(rt_pernr) TYPE hcm_pernr_table .
    METHODS get_saved_bonuses
      IMPORTING
        !iv_gjahr         TYPE gjahr
        !iv_quarter       TYPE z_sal_quarter_e_mau
      RETURNING
        VALUE(rt_bonuses) TYPE ztt_sal_bonus_mau .
    METHODS get_employee_invoices
      IMPORTING
        VALUE(iv_pernr)    TYPE persno
        VALUE(iv_begda)    TYPE datum
        VALUE(iv_endda)    TYPE datum
      RETURNING
        VALUE(rt_invocies) TYPE ztt_sal_employee_invocies_mau .
    METHODS get_target_data
      IMPORTING
        !iv_begda         TYPE datum
        !iv_endda         TYPE datum
        !iv_gjahr         TYPE gjahr
        !iv_quarter       TYPE z_sal_quarter_e_mau
      RETURNING
        VALUE(rt_targets) TYPE ztt_sal_targets_mau .
    METHODS get_sal_turnover
      IMPORTING
        !iv_begda                 TYPE datum
        !iv_endda                 TYPE datum
        !iv_quarter               TYPE z_sal_quarter_e_mau
        !iv_gjahr                 TYPE gjahr
      RETURNING
        VALUE(rt_turnover_buffer) TYPE ztt_sal_turnover_mau .
  PROTECTED SECTION.

  PRIVATE SECTION.

    DATA mv_parvw_employee_responsible TYPE parvw .

    METHODS lock_data
      IMPORTING
        !it_bonus_data TYPE ztt_sal_bonus_mau
      RAISING
        cx_abap_lock_failure .
    METHODS unlock_data
      IMPORTING
        !it_bonus_data TYPE ztt_sal_bonus_mau .
ENDCLASS.



CLASS ZCL_SAL_BONUS_DB_MAU IMPLEMENTATION.


  METHOD lock_data.
    " Check if if there is anything to block
    IF it_bonus_data IS INITIAL. RETURN. ENDIF.

    CALL FUNCTION 'ENQUEUE_EZ_SAL_BONUS_MAU'
      EXPORTING
        mode_zmau_sal_bonus = 'E'
        mandt               = sy-mandt
        pernr               = it_bonus_data[ 1 ]-pernr
        gjahr               = it_bonus_data[ 1 ]-gjahr
        quarter             = it_bonus_data[ 1 ]-quarter
        waerk               = it_bonus_data[ 1 ]-waerk
      EXCEPTIONS
        foreign_lock        = 1
        system_failure      = 2
        OTHERS              = 3.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_abap_lock_failure.
    ENDIF.

  ENDMETHOD.


  METHOD save_calculated_bonuses.
    rv_success = abap_false.

    IF it_bonus_data IS INITIAL.
      MESSAGE e003(zms_sal_mau) INTO ev_message.
      RETURN.
    ENDIF.

    TRY.
        " Setting up the lock
        me->lock_data( it_bonus_data ).

        " Save/upadate the DB table with bonuses
        MODIFY zmau_sal_bonus FROM TABLE it_bonus_data.

        IF sy-subrc <> 0.
          MESSAGE e004(zms_sal_mau) INTO ev_message.
          me->unlock_data( it_bonus_data ).
          RETURN.
        ENDIF.

        IF it_target_data IS NOT INITIAL.
          MODIFY zmau_sal_targets FROM TABLE it_target_data.

          IF sy-subrc <> 0.
            MESSAGE e004(zms_sal_mau) INTO ev_message.
            me->unlock_data( it_bonus_data ).
            RETURN.
          ENDIF.
        ENDIF.

        " If both writes were successful, save the changes to the database
        COMMIT WORK.
        rv_success = abap_true.
        MESSAGE i005(zms_sal_mau) INTO ev_message.

        " Dequeue after successful commit
        me->unlock_data( it_bonus_data ).

      CATCH cx_abap_lock_failure.
        MESSAGE w005(zms_sal_mau) INTO ev_message.

      CATCH cx_root.
        " Recovery logic – if anything goes wrong, roll back the entire database transaction
        ROLLBACK WORK.
        MESSAGE e004(zms_sal_mau) INTO ev_message.
    ENDTRY.

    IF rv_success = abap_false.
      me->unlock_data( it_bonus_data ).
    ENDIF.

  ENDMETHOD.


  METHOD unlock_data.
    " Check if if there is anything to unlock
    IF it_bonus_data IS INITIAL. RETURN. ENDIF.

    CALL FUNCTION 'DEQUEUE_EZ_SAL_BONUS_MAU'
      EXPORTING
        mode_zmau_sal_bonus = 'E'
        mandt               = sy-mandt
        pernr               = it_bonus_data[ 1 ]-pernr
        gjahr               = it_bonus_data[ 1 ]-gjahr
        quarter             = it_bonus_data[ 1 ]-quarter
        waerk               = it_bonus_data[ 1 ]-waerk.
  ENDMETHOD.


  METHOD constructor.
    " translate the visible partner function 'ER' into the database's internal technical code
    CALL FUNCTION 'CONVERSION_EXIT_PARVW_INPUT'
      EXPORTING
        input  = 'ER'
      IMPORTING
        output = me->mv_parvw_employee_responsible.
  ENDMETHOD.


  METHOD get_active_employees.
    " A query that returns only active employees
    " who have a specific sales target for a given period
    SELECT zmau_sal_targets~pernr
      FROM zmau_sal_targets
     INNER JOIN pa0001
        ON pa0001~pernr = zmau_sal_targets~pernr
       AND pa0001~begda <= @iv_begda
       AND pa0001~endda >= @iv_endda
     WHERE gjahr = @iv_gjahr
       AND quarter = @iv_quarter
      INTO TABLE @rt_pernr.
  ENDMETHOD.


  METHOD get_employee_invoices.
*    Attempt to retrieve invoices from the database
    SELECT vbpa~pernr, vbrk~vbeln, vbrk~fkdat, vbrk~waerk, vbrk~fksto, vbrk~netwr, vbpa~parvw
      FROM vbrk
     INNER JOIN vbpa ON vbrk~vbeln = vbpa~vbeln
     WHERE vbpa~pernr = @iv_pernr
       AND vbrk~fkdat BETWEEN @iv_begda AND @iv_endda
       AND vbrk~fksto = @abap_false
       AND vbpa~parvw = @me->mv_parvw_employee_responsible
      INTO CORRESPONDING FIELDS OF TABLE @rt_invocies.

*--------------------------------------------------------------------*
*    If the DB table vbrk is empty, select data from test ainvocies table
    IF rt_invocies IS INITIAL.
      SELECT zmau_test_inv~pernr, zmau_test_inv~vbeln, zmau_test_inv~fkdat, zmau_test_inv~fksto,
             zmau_test_inv~waerk, zmau_test_inv~parvw, zmau_test_inv~netwr
        FROM zmau_test_inv
       WHERE zmau_test_inv~pernr = @iv_pernr
         AND zmau_test_inv~fkdat BETWEEN @iv_begda AND @iv_endda
         AND zmau_test_inv~fksto = @abap_false
         AND zmau_test_inv~parvw = @me->mv_parvw_employee_responsible
        INTO CORRESPONDING FIELDS OF TABLE @rt_invocies.
    ENDIF.
*--------------------------------------------------------------------*
  ENDMETHOD.


  METHOD get_sal_turnover.
    " Retrieving and summarizing employee turnover for a given period
    " Standard database query (to the buffer)
    SELECT @iv_gjahr AS gjahr, @iv_quarter AS quarter, SUM( vbrk~netwr ) AS turnover, vbrk~waerk, vbpa~pernr
      FROM vbrk
      INNER JOIN vbpa ON vbrk~vbeln = vbpa~vbeln
      WHERE fkdat BETWEEN @iv_begda AND @iv_endda
      AND fksto IS INITIAL
      AND parvw = @me->mv_parvw_employee_responsible
      GROUP BY vbpa~pernr, vbrk~waerk
      INTO CORRESPONDING FIELDS OF TABLE @rt_turnover_buffer.

*--------------------------------------------------------------------*
*      Solution for the presentation: if the table is empty, use test data
*--------------------------------------------------------------------*
    IF rt_turnover_buffer IS INITIAL.
*      Retrieve employees for whom sales targets have been set
      SELECT @iv_gjahr AS gjahr, @iv_quarter AS quarter, SUM( netwr ) AS turnover, waerk, pernr
        FROM zmau_test_inv
        WHERE fkdat BETWEEN @iv_begda AND @iv_endda
        AND fksto IS INITIAL
        AND parvw = @me->mv_parvw_employee_responsible
        GROUP BY pernr, waerk
        INTO CORRESPONDING FIELDS OF TABLE @rt_turnover_buffer.
    ENDIF.
*--------------------------------------------------------------------*

  ENDMETHOD.


  METHOD get_saved_bonuses.
    SELECT pernr, gjahr, quarter, waerk, target_value, actual_turnover, bonus_amt, approve_status
      FROM zmau_sal_bonus
     WHERE gjahr     = @iv_gjahr
       AND quarter   = @iv_quarter
      INTO CORRESPONDING FIELDS OF TABLE @rt_bonuses.
  ENDMETHOD.


  METHOD get_target_data.
    " Retrieve the employees and their defined sales targets for a specific year and quarter from the table i
    SELECT zmau_sal_targets~mandt, zmau_sal_targets~pernr, zmau_sal_targets~quarter, zmau_sal_targets~gjahr,
           zmau_sal_targets~target_value, zmau_sal_targets~waerk, pa0001~sname
      FROM zmau_sal_targets
     INNER JOIN pa0001
        ON zmau_sal_targets~pernr = pa0001~pernr
       AND pa0001~begda <= @iv_begda
       AND pa0001~endda >= @iv_endda
     WHERE zmau_sal_targets~quarter = @iv_quarter
       AND zmau_sal_targets~gjahr   = @iv_gjahr
INTO CORRESPONDING FIELDS OF TABLE @rt_targets.

  ENDMETHOD.
ENDCLASS.
