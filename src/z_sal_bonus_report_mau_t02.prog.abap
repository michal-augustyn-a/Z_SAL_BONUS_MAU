*&---------------------------------------------------------------------*
*& Include z_sal_bonus_report_mau_t01
*&---------------------------------------------------------------------*

*Class that manages navigation in the ALV report
CLASS lcl_navigation_manager DEFINITION.
  PUBLIC SECTION.
    METHODS handle_double_click FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING
        !e_row
        !e_column.

    METHODS handle_edit_target.

    METHODS save_draft_target.

    METHODS approve_bonus.

    PRIVATE SECTION.
      METHODS execute_save
        IMPORTING
          iv_approve_status TYPE z_sal_approve_status_e_mau.
ENDCLASS.
