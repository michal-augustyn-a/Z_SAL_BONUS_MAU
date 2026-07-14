*&---------------------------------------------------------------------*
*& Include          Z_SAL_BONUS_REPORT_MAU_SEL
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_gjahr TYPE gjahr OBLIGATORY,
              p_quart TYPE z_sal_quarter_e_mau OBLIGATORY AS LISTBOX VISIBLE LENGTH 15.
SELECTION-SCREEN END OF BLOCK b1.
