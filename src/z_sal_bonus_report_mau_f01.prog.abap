*&---------------------------------------------------------------------*
*& Include          Z_SAL_BONUS_REPORT_MAU_FORMS
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form initialize_selection_screen
*&---------------------------------------------------------------------*
FORM initialize_selection_screen .
  " Setting the current year, sy-datum(4) takes the first 4 characters from the system date (YYYY)
  p_gjahr = sy-datum(4).

  " Calculating the current quarter and initializing current year, extract the month (items 4 and 5 from the sy-datum, i.e. MM)
  DATA(lv_month) = sy-datum+4(2).

  " Months 1, 2, 3 -> Quarter 1, etc.
  CASE lv_month.
    WHEN '01' OR '02' OR '03'. p_quart = 1.
    WHEN '04' OR '05' OR '06'. p_quart = 2.
    WHEN '07' OR '08' OR '09'. p_quart = 3.
    WHEN '10' OR '11' OR '12'. p_quart = 4.
  ENDCASE.

  p_quart = 1. " Only for testing

ENDFORM.
