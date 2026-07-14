*&---------------------------------------------------------------------*
*& Include          Z_SAL_BONUS_REPORT_MAU_F02
*&---------------------------------------------------------------------*

CLASS lcl_navigation_manager IMPLEMENTATION.

  METHOD handle_double_click.
    DATA: lr_sal_monitor_tab_ref TYPE REF TO data.

    lr_sal_monitor_tab_ref = gr_bonus_service->get_sal_monitor_tab_ref( ).

    FIELD-SYMBOLS: <lt_sal_monitor_data> TYPE ztt_sal_monitor_alv_mau.
    ASSIGN lr_sal_monitor_tab_ref->* TO <lt_sal_monitor_data>.

    READ TABLE <lt_sal_monitor_data> ASSIGNING FIELD-SYMBOL(<fs_row>) INDEX e_row-index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE e_column-fieldname.
      WHEN 'SNAME'.
        SET PARAMETER ID 'PER' FIELD <fs_row>-pernr.
        CALL TRANSACTION 'PA20' AND SKIP FIRST SCREEN.

      WHEN OTHERS.
        gv_selected_pernr = <fs_row>-pernr.
        gv_selected_sname = <fs_row>-sname.

        CALL SCREEN 0200.
    ENDCASE.
  ENDMETHOD.


  METHOD handle_edit_target.
    DATA: lt_selected_rows         TYPE lvc_t_row,
          lr_sal_monitor_table_ref TYPE REF TO data,
          lt_fields                TYPE TABLE OF sval,
          ls_field                 TYPE sval,
          lv_returncode            TYPE c,
          lv_row_idx               TYPE i,
          lv_text_input            TYPE string.

    FIELD-SYMBOLS: <lt_monitor_data> TYPE ztt_sal_monitor_alv_mau.

    " Selected rows on the alv grid 100
    gr_grid_100->get_selected_rows( IMPORTING et_index_rows = lt_selected_rows ).

    " Checking that exactly one employee has been selected, one row
    IF lines( lt_selected_rows ) <> 1.
      MESSAGE w007(zms_sal_mau) DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    lr_sal_monitor_table_ref = gr_bonus_service->get_sal_monitor_tab_ref( ).
    ASSIGN lr_sal_monitor_table_ref->* TO <lt_monitor_data>.

    lv_row_idx = lt_selected_rows[ 1 ]-index.
    ASSIGN <lt_monitor_data>[ lv_row_idx ] TO FIELD-SYMBOL(<ls_alv_row>).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Protection. Has the status already been approved?
    IF <ls_alv_row>-approve_status = zcl_sal_bonus_service_mau=>mc_status_approved.
      MESSAGE e008(zms_sal_mau) DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    " Popup window
    CLEAR ls_field.
    ls_field-tabname   = 'BSEG'.
    ls_field-fieldname = 'WRBTR'.
    ls_field-fieldtext = 'New Target Value'.
    ls_field-value     = <ls_alv_row>-target_value.
    ls_field-field_attr = ' '.            " To edit
    APPEND ls_field TO lt_fields.

    CLEAR ls_field.
    ls_field-tabname    = 'BSEG'.
    ls_field-fieldname  = 'H_WAERS'.      " Currency field
    ls_field-value      = <ls_alv_row>-waerk.
    ls_field-field_attr = '02'.           " Locked for editing
    APPEND ls_field TO lt_fields.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title     = 'Change Target Value'
        start_column    = '6'
        start_row       = '6'
      IMPORTING
        returncode      = lv_returncode
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.

    IF sy-subrc <> 0.
      MESSAGE e009(zms_sal_mau) DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    " Processing the result after user confirmation
    IF lv_returncode <> zcl_sal_bonus_service_mau=>mc_status_approved.
      lv_text_input = lt_fields[ 1 ]-value.
      CONDENSE lv_text_input NO-GAPS.

      TRY.
          <ls_alv_row>-target_value = lv_text_input.

          " Recalculate the row using the updated values
          gr_bonus_service->recalculate_single_row( CHANGING cs_alv = <ls_alv_row> ).

          " Refresh the screen display, icons, percentages and totals
          gr_grid_100->refresh_table_display( ).

          MESSAGE s010(zms_sal_mau) DISPLAY LIKE 'I'.

        CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
          MESSAGE e011(zms_sal_mau) DISPLAY LIKE 'I'.
      ENDTRY.
    ENDIF.

  ENDMETHOD.

  METHOD save_draft_target.
    me->execute_save( iv_approve_status = zcl_sal_bonus_service_mau=>mc_status_draft ). " Empty status ' ' - draft
  ENDMETHOD.

  METHOD approve_bonus.
    me->execute_save( iv_approve_status = zcl_sal_bonus_service_mau=>mc_status_approved ). " Status A - Sales bonus approved
  ENDMETHOD.

  METHOD execute_save.
    DATA: lr_sal_monitor_tab_ref TYPE REF TO data,
          lt_selected_rows       TYPE lvc_t_row,
          ls_selected_row        TYPE lvc_s_row,
          lt_targets_to_save     TYPE ztt_sal_targets_mau,
          lt_bonus_to_save       TYPE ztt_sal_bonus_mau,
          lv_msg                 TYPE string,
          lv_skipped_count       TYPE i,
          lv_saved_count         TYPE i.

    gr_grid_100->get_selected_rows( IMPORTING et_index_rows = lt_selected_rows ).

    IF lt_selected_rows IS INITIAL.
      MESSAGE w012(zms_sal_mau) DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    lr_sal_monitor_tab_ref = gr_bonus_service->get_sal_monitor_tab_ref( ).

    FIELD-SYMBOLS: <lt_monitor_data> TYPE ztt_sal_monitor_alv_mau.
    ASSIGN lr_sal_monitor_tab_ref->* TO <lt_monitor_data>.

    LOOP AT lt_selected_rows INTO ls_selected_row.
      ASSIGN <lt_monitor_data>[ ls_selected_row-index ] TO FIELD-SYMBOL(<ls_alv_row>).

      IF sy-subrc = 0.
        IF <ls_alv_row>-approve_status = zcl_sal_bonus_service_mau=>mc_status_approved.
          lv_skipped_count = lv_skipped_count + 1.
          CONTINUE.
        ENDIF.

        APPEND VALUE zmau_sal_bonus(
          pernr            = <ls_alv_row>-pernr
          gjahr            = <ls_alv_row>-gjahr
          quarter          = <ls_alv_row>-quarter
          target_value     = <ls_alv_row>-target_value
          actual_turnover  = <ls_alv_row>-actual_turnover
          bonus_amt        = <ls_alv_row>-bonus_amount
          waerk            = <ls_alv_row>-waerk
          approve_status   = iv_approve_status " imported parameter
          approved_by      = sy-uname
          approved_date    = sy-datum
          approved_at_time = sy-uzeit
        ) TO lt_bonus_to_save.

        APPEND VALUE zmau_sal_targets(
          pernr        = <ls_alv_row>-pernr
          gjahr        = <ls_alv_row>-gjahr
          quarter      = <ls_alv_row>-quarter
          target_value = <ls_alv_row>-target_value
        ) TO lt_targets_to_save.

        <ls_alv_row>-approve_status = iv_approve_status.
        lv_saved_count = lv_saved_count + 1.

      ENDIF.
    ENDLOOP.

    IF lt_bonus_to_save IS INITIAL AND lv_skipped_count > 0.
      MESSAGE w013(zms_sal_mau) WITH lv_skipped_count DISPLAY LIKE 'I'.
      RETURN.
    ENDIF.

    IF gr_db->save_calculated_bonuses(
      EXPORTING
        it_bonus_data = lt_bonus_to_save
        it_target_data = lt_targets_to_save
      IMPORTING
        ev_message = lv_msg ) = abap_true.

      IF iv_approve_status = zcl_sal_bonus_service_mau=>mc_status_approved.
        MESSAGE s014(zms_sal_mau) WITH lv_saved_count DISPLAY LIKE 'I'.
      ELSE.
        MESSAGE s015(zms_sal_mau) WITH lv_saved_count DISPLAY LIKE 'I'.
      ENDIF.

    ELSE.
      " Rollback of approve status in case of a database error
      LOOP AT lt_selected_rows INTO ls_selected_row.
        IF line_exists( <lt_monitor_data>[ ls_selected_row-index ] ).
          <lt_monitor_data>[ ls_selected_row-index ]-approve_status = zcl_sal_bonus_service_mau=>mc_status_draft.
        ENDIF.
      ENDLOOP.

      MESSAGE lv_msg TYPE 'E' DISPLAY LIKE 'I'.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
