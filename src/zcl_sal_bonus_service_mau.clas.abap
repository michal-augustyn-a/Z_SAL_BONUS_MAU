CLASS zcl_sal_bonus_service_mau DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS: mc_q1 TYPE z_sal_quarter_e_mau VALUE 1,
               mc_q2 TYPE z_sal_quarter_e_mau VALUE 2,
               mc_q3 TYPE z_sal_quarter_e_mau VALUE 3,
               mc_q4 TYPE z_sal_quarter_e_mau VALUE 4.

    CONSTANTS: mc_bonus_rate_mid          TYPE p DECIMALS 2 VALUE '0.01',     " 0.01 = 1% of turnover
               mc_bonus_rate_normal       TYPE p DECIMALS 2 VALUE '0.025',    " 0.025 = 2.5%
               mc_first_bonus_milestone   TYPE i VALUE 80,
               mc_second_bonus_milestone  TYPE i VALUE 100.

    CONSTANTS: mc_status_approved TYPE z_sal_approve_status_e_mau VALUE 'A',
               mc_status_draft    TYPE z_sal_approve_status_e_mau VALUE ' '.

    METHODS constructor
      IMPORTING
        !io_db      TYPE REF TO zcl_sal_bonus_db_mau
        !iv_gjahr   TYPE gjahr
        !iv_quarter TYPE z_sal_quarter_e_mau .
    METHODS build_and_calculate_monitor .
    METHODS recalculate_single_row
      CHANGING
        !cs_alv TYPE zst_sal_monitor_alv_mau .
    METHODS get_sal_monitor_tab_ref
      RETURNING
        VALUE(rr_sal_monitor_data_ref) TYPE REF TO data .
    CLASS-METHODS get_quarter_dates
      IMPORTING
        VALUE(iv_gjahr)       TYPE gjahr
        VALUE(iv_quarter)     TYPE z_sal_quarter_e_mau
      EXPORTING
        VALUE(ev_begin_datum) TYPE datum
        VALUE(ev_end_datum)   TYPE datum .
    METHODS get_begin_date
      RETURNING
        VALUE(rv_begda) TYPE datum .
    METHODS get_end_date
      RETURNING
        VALUE(rv_endda) TYPE datum .
  PROTECTED SECTION.

  PRIVATE SECTION.

    DATA mo_db                        TYPE REF TO zcl_sal_bonus_db_mau .
    DATA mv_gjahr                     TYPE gjahr .
    DATA mv_quarter                   TYPE z_sal_quarter_e_mau .
    DATA mv_begin_datum               TYPE datum .
    DATA mv_end_datum                 TYPE datum .
    DATA mt_sal_target_buffer         TYPE ztt_sal_targets_mau .
    DATA mt_sal_turnover_buffer       TYPE ztt_sal_turnover_mau .
    DATA mt_sal_all_invocies_buffer   TYPE ztt_sal_employee_invocies_mau .
    DATA mt_sal_monitor_data          TYPE ztt_sal_monitor_alv_mau .

    METHODS map_data_from_buffer
      CHANGING
        !cs_alv TYPE zst_sal_monitor_alv_mau .
    METHODS calculate_sal_pct
      CHANGING
        !cs_alv TYPE zst_sal_monitor_alv_mau .
    METHODS determine_bonus_amount
      CHANGING
        !cs_alv TYPE zst_sal_monitor_alv_mau .
    METHODS determine_bonus_lvl_status
      CHANGING
        !cs_alv TYPE zst_sal_monitor_alv_mau .
ENDCLASS.



CLASS ZCL_SAL_BONUS_SERVICE_MAU IMPLEMENTATION.


  METHOD calculate_sal_pct.
*     Calculating target achievement
*     Target achievement = (turnover / target) * 100%
    IF cs_alv-target_value > 0.
      cs_alv-achievement_pct = cs_alv-actual_turnover / cs_alv-target_value * '100.00'.
    ELSE.
      cs_alv-achievement_pct = 0.
    ENDIF.
  ENDMETHOD.


  METHOD determine_bonus_amount.
*     Bonus milestones. Calculating bonuses based on target achievement
*     Bonus = turnover * 1–5%
    IF cs_alv-achievement_pct < me->mc_first_bonus_milestone.
      cs_alv-bonus_amount = 0.
    ELSEIF cs_alv-achievement_pct BETWEEN me->mc_first_bonus_milestone AND me->mc_second_bonus_milestone.
      cs_alv-bonus_amount = cs_alv-actual_turnover * me->mc_bonus_rate_mid. " % turnonver
    ELSEIF cs_alv-achievement_pct > me->mc_second_bonus_milestone.
      cs_alv-bonus_amount = cs_alv-actual_turnover * me->mc_bonus_rate_normal. " % turnover
    ENDIF.
  ENDMETHOD.


  METHOD determine_bonus_lvl_status.
    " Assigning icons based on achievement level
    IF cs_alv-achievement_pct < me->mc_first_bonus_milestone.
      cs_alv-bonus_lvl_status =  icon_red_light.                      " low level bonus
    ELSEIF cs_alv-achievement_pct BETWEEN me->mc_first_bonus_milestone AND me->mc_second_bonus_milestone.
      cs_alv-bonus_lvl_status = icon_yellow_light.                    " mid level bonus
    ELSEIF cs_alv-achievement_pct > me->mc_second_bonus_milestone.
      cs_alv-bonus_lvl_status = icon_green_light.                     " high level bonus
    ENDIF.
  ENDMETHOD.


  METHOD get_quarter_dates.
*    A supporting method for determining the start and end of a quarter
    CLEAR: ev_begin_datum,
           ev_end_datum.

    CASE iv_quarter.

      WHEN zcl_sal_bonus_service_mau=>mc_q1.
        ev_begin_datum  = iv_gjahr && '0101'.
        ev_end_datum    = iv_gjahr && '0331'.

      WHEN zcl_sal_bonus_service_mau=>mc_q2.
        ev_begin_datum  = iv_gjahr && '0401'.
        ev_end_datum    = iv_gjahr && '0630'.

      WHEN zcl_sal_bonus_service_mau=>mc_q3.
        ev_begin_datum  = iv_gjahr && '0701'.
        ev_end_datum    = iv_gjahr && '0930'.

      WHEN zcl_sal_bonus_service_mau=>mc_q4.
        ev_begin_datum  = iv_gjahr && '1001'.
        ev_end_datum    = iv_gjahr && '1231'.
    ENDCASE.

  ENDMETHOD.


  METHOD map_data_from_buffer.
*     Reading out the target for an employee
    READ TABLE me->mt_sal_target_buffer
      ASSIGNING FIELD-SYMBOL(<fs_target>)
      WITH KEY pernr = cs_alv-pernr.

    IF sy-subrc = 0.
      cs_alv-sname        = <fs_target>-sname.
      cs_alv-gjahr        = <fs_target>-gjahr.
      cs_alv-quarter      = <fs_target>-quarter.
      cs_alv-target_value = <fs_target>-target_value.
      cs_alv-waerk        = <fs_target>-waerk.
    ENDIF.

*     Reading the turnover for an employee
    READ TABLE me->mt_sal_turnover_buffer
      ASSIGNING FIELD-SYMBOL(<fs_turnover>)
      WITH KEY pernr = cs_alv-pernr.

    IF sy-subrc = 0.
      cs_alv-actual_turnover  = <fs_turnover>-turnover.
      cs_alv-waerk            = <fs_turnover>-waerk.
    ENDIF.
  ENDMETHOD.


  METHOD recalculate_single_row.
    me->calculate_sal_pct( CHANGING cs_alv = cs_alv ).
    me->determine_bonus_amount( CHANGING cs_alv = cs_alv ).
    me->determine_bonus_lvl_status( CHANGING cs_alv = cs_alv ).
  ENDMETHOD.


  METHOD build_and_calculate_monitor.
    DATA: lt_active_pernrs TYPE hcm_pernr_table,
          lt_saved_bonuses TYPE ztt_sal_bonus_mau.

    lt_active_pernrs = me->mo_db->get_active_employees(
                              iv_begda   = me->mv_begin_datum
                              iv_endda   = me->mv_end_datum
                              iv_gjahr   = me->mv_gjahr
                              iv_quarter = me->mv_quarter
                              ).

    IF lt_active_pernrs IS INITIAL.
      MESSAGE w000(zms_sal_mau) DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    MOVE-CORRESPONDING lt_active_pernrs TO me->mt_sal_monitor_data.

    " Filling buffers with actual target, and turnover
    me->mt_sal_target_buffer = mo_db->get_target_data( iv_begda = mv_begin_datum iv_endda = mv_end_datum iv_quarter = mv_quarter iv_gjahr = mv_gjahr ).
    me->mt_sal_turnover_buffer = mo_db->get_sal_turnover( iv_begda = mv_begin_datum iv_endda = mv_end_datum iv_quarter = mv_quarter iv_gjahr = mv_gjahr ).

    " Retrieving data that have already been approved or saved as a draft in zmau_sal_bonus
    lt_saved_bonuses = me->mo_db->get_saved_bonuses(
                                  iv_gjahr    = me->mv_gjahr
                                  iv_quarter  = me->mv_quarter
                                  ).

    " Calculation loop
    LOOP AT me->mt_sal_monitor_data ASSIGNING FIELD-SYMBOL(<fs_alv_row>).
      " Retrieve the latest data from the buffers (turnovers and targets)
      me->map_data_from_buffer( CHANGING cs_alv = <fs_alv_row> ).

      " Checking whether an employee already has an entry in the bonus db table
      READ TABLE lt_saved_bonuses ASSIGNING FIELD-SYMBOL(<fs_saved>)
        WITH KEY pernr = <fs_alv_row>-pernr.

      IF sy-subrc = 0.
        " If there is an entry in the database,
        " Always restore the saved status (e.g. Draft ' ' or Approved 'A')
        <fs_alv_row>-approve_status = <fs_saved>-approve_status.

        " If the bonus has been finnaly APPROVED, also freeze the target_value at that point
        IF <fs_saved>-approve_status = me->mc_status_approved.
          <fs_alv_row>-target_value     = <fs_saved>-target_value.
          <fs_alv_row>-actual_turnover  = <fs_saved>-actual_turnover. " Overwrite the current turnover with the historical turnover
          <fs_alv_row>-bonus_amount     = <fs_saved>-bonus_amt.       " Restore the historical bonus amount
        ENDIF.
      ENDIF.

      " Calculate only those records that do not have a confirmed status 'A'
      CASE <fs_alv_row>-approve_status.
        WHEN me->mc_status_draft.
          me->calculate_sal_pct( CHANGING cs_alv = <fs_alv_row> ).
          me->determine_bonus_amount( CHANGING cs_alv = <fs_alv_row> ).
          me->determine_bonus_lvl_status( CHANGING cs_alv = <fs_alv_row> ).
        WHEN me->mc_status_approved.
          " For approved, calculate only the percentage and icon status based on the frozen values
          me->calculate_sal_pct( CHANGING cs_alv = <fs_alv_row> ).
          me->determine_bonus_lvl_status( CHANGING cs_alv = <fs_alv_row> ).
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD constructor.
    me->mo_db      = io_db.
    me->mv_gjahr   = iv_gjahr.
    me->mv_quarter = iv_quarter.

    " calculate the dates once for the entire class instance
    me->get_quarter_dates(
      EXPORTING iv_gjahr        = me->mv_gjahr
                iv_quarter      = me->mv_quarter
      IMPORTING ev_begin_datum  = me->mv_begin_datum
                ev_end_datum    = me->mv_end_datum ).
  ENDMETHOD.


  METHOD get_sal_monitor_tab_ref.
    " retrieve a reference to internal instance table
    GET REFERENCE OF me->mt_sal_monitor_data INTO rr_sal_monitor_data_ref.
  ENDMETHOD.


  METHOD get_begin_date.
    rv_begda = me->mv_begin_datum.
  ENDMETHOD.


  METHOD get_end_date.
    rv_endda = me->mv_end_datum.
  ENDMETHOD.
ENDCLASS.
