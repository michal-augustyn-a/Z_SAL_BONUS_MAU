*&---------------------------------------------------------------------*
*& Include          Z_SAL_BONUS_REPORT_MAU_O01
*&---------------------------------------------------------------------*

MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR 'TITLE_0100'.
ENDMODULE.
*&---------------------------------------------------------------------*
*& Module DISPLAY_ALV_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE display_alv_0100 OUTPUT.
  DATA: lt_fc                  TYPE lvc_t_fcat,
        ls_layout              TYPE lvc_s_layo,
        lt_sort                TYPE lvc_t_sort,
        lr_sal_monitor_tab_ref TYPE REF TO data.

  " retrieve a reference from the service to the data table that resides in the object
  lr_sal_monitor_tab_ref = gr_bonus_service->get_sal_monitor_tab_ref( ).


  IF gr_container_100 IS NOT INITIAL.
    gr_grid_100->refresh_table_display( ).
    RETURN.
  ENDIF.

  gr_nav_manager    = NEW lcl_navigation_manager( ).
  gr_container_100  = NEW cl_gui_custom_container( container_name = 'CC_ALV_100' ).
  gr_grid_100       = NEW cl_gui_alv_grid( i_parent = gr_container_100 ).

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
*     I_BUFFER_ACTIVE        =
      i_structure_name       = 'ZST_SAL_MONITOR_ALV_MAU'
      i_client_never_display = 'X'
*     I_BYPASSING_BUFFER     =
*     I_INTERNAL_TABNAME     =
    CHANGING
      ct_fieldcat            = lt_fc
    EXCEPTIONS
      inconsistent_interface = 1
      program_error          = 2
      OTHERS                 = 3.

  " Column configuration
  LOOP AT lt_fc ASSIGNING FIELD-SYMBOL(<fs_fc>).
    CASE <fs_fc>-fieldname.
      WHEN 'TARGET_VALUE' OR 'ACTUAL_TURNOVER' OR 'BONUS_AMOUNT'.
        <fs_fc>-do_sum = abap_true.
        <fs_fc>-just = 'R'. " Right alligned

      WHEN 'ACHIEVEMENT_PCT'.
        <fs_fc>-just = 'R'.

      WHEN 'BONUS_LVL_STATUS'.
        <fs_fc>-icon = abap_true.
        <fs_fc>-just   = 'C'. " Centered

      WHEN 'PERNR' OR 'GJAHR' OR 'QUARTER' OR 'APPROVE_STATUS'.
        <fs_fc>-just   = 'C'. " Centered

      WHEN 'SNAME' OR 'WAERK'.
        <fs_fc>-just   = 'L'.

      WHEN OTHERS.
    ENDCASE.
  ENDLOOP.

  ls_layout-zebra = abap_true.
  ls_layout-cwidth_opt = abap_true.

  "Sortowanie
  lt_sort = VALUE #( ( fieldname = 'PERNR' up = abap_true ) ).

  CALL METHOD gr_grid_100->set_table_for_first_display
    EXPORTING
      is_layout                     = ls_layout
    CHANGING
      it_outtab                     = lr_sal_monitor_tab_ref->*
      it_fieldcatalog               = lt_fc
      it_sort                       = lt_sort
    EXCEPTIONS
      invalid_parameter_combination = 1
      program_error                 = 2
      too_many_lines                = 3
      OTHERS                        = 4.

  IF sy-subrc <> 0.
    MESSAGE e001(zms_sal_mau) DISPLAY LIKE 'I'.
  ENDIF.

  SET HANDLER gr_nav_manager->handle_double_click FOR gr_grid_100.

  gr_grid_100->set_toolbar_interactive( ).
  gr_grid_100->set_ready_for_input( i_ready_for_input = 1 ).
  gr_grid_100->register_edit_event( cl_gui_alv_grid=>mc_evt_modified ).

ENDMODULE.


*&---------------------------------------------------------------------*
*& Module STATUS_0200 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0200 OUTPUT.
  SET PF-STATUS 'STATUS_0200'.
  SET TITLEBAR 'TITLE_0200'.
ENDMODULE.

*&---------------------------------------------------------------------*
*& Module DISPLAY_ALV_0200 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE display_alv_0200 OUTPUT.
  gt_sal_employee_invocies = gr_db->get_employee_invoices(
                                iv_pernr = gv_selected_pernr
                                iv_begda = gv_begda
                                iv_endda = gv_endda
                                ).

  IF gr_container_200 IS NOT INITIAL.
    gr_salv_200->set_data( CHANGING t_table = gt_sal_employee_invocies ).
    gr_salv_200->refresh( ).
    RETURN.
  ENDIF.

  gr_container_200 = NEW cl_gui_custom_container( container_name = 'CC_ALV_200' ).

  TRY.
      cl_salv_table=>factory(
        EXPORTING
          r_container = gr_container_200
        IMPORTING
          r_salv_table = gr_salv_200
        CHANGING
          t_table = gt_sal_employee_invocies ).

      gr_salv_200->get_functions( )->set_all( abap_true ).
      gr_salv_200->display( ).

    CATCH cx_salv_msg.
      MESSAGE e002(zms_sal_mau) DISPLAY LIKE 'I'.
  ENDTRY.

ENDMODULE.
