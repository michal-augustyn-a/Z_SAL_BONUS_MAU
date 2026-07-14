*&---------------------------------------------------------------------*
*& Include          Z_SAL_BONUS_REPORT_MAU_I01
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*&      text
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'EDIT_TRGT'.
      gr_nav_manager->handle_edit_target( ).
    WHEN 'UPDAT_TRGT'.
      gr_nav_manager->save_draft_target( ).
    WHEN 'APPROVE'.
      gr_nav_manager->approve_bonus( ).
    WHEN 'BACK'.
      LEAVE TO SCREEN 0.        " Return to previous screen
    WHEN 'EXIT' OR 'CANC'.
      LEAVE PROGRAM.
  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0200  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0200 INPUT.
  save_ok = ok_code.
  CLEAR ok_code.

  CASE save_ok.
    WHEN 'BACK'.
      LEAVE TO SCREEN 0. " Return to previous screen
    WHEN 'EXIT' OR 'CANC'.
      LEAVE PROGRAM.
  ENDCASE.

  CLEAR ok_code.
ENDMODULE.
