*&---------------------------------------------------------------------*
*& Report Z_SAL_BONUS_REPORT_MAU               - Report Z_SAL_BONUS_REPORT_MAU
*&---------------------------------------------------------------------*

REPORT z_sal_bonus_report_mau.

INCLUDE z_sal_bonus_report_mau_t01.     " Top
INCLUDE z_sal_bonus_report_mau_t02.     " Definition lcl_navigation_manager
INCLUDE z_sal_bonus_report_mau_sel.     " Selection screen
INCLUDE z_sal_bonus_report_mau_o01.     " PBO
INCLUDE z_sal_bonus_report_mau_i01.     " PAI
INCLUDE z_sal_bonus_report_mau_f01.     " Forms
INCLUDE z_sal_bonus_report_mau_f02.     " Implementation lcl_navigation_manager

INITIALIZATION.
  PERFORM initialize_selection_screen.  " Setting up the current year and quarter

START-OF-SELECTION.
  gr_db            = NEW zcl_sal_bonus_db_mau( ).   " CRUD layer
  gr_bonus_service = NEW zcl_sal_bonus_service_mau( io_db = gr_db iv_gjahr = p_gjahr iv_quarter = p_quart ).    " Service class, calculations, assigning statuses

  gv_begda = gr_bonus_service->get_begin_date( ).
  gv_endda = gr_bonus_service->get_end_date( ).

  gr_bonus_service->build_and_calculate_monitor( ).

  CALL SCREEN 0100.

END-OF-SELECTION.
