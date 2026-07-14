*&---------------------------------------------------------------------*
*& Include Z_SAL_BONUS_REPORT_MAU_T01    - Report Z_SAL_BONUS_REPORT_MAU
*&---------------------------------------------------------------------*

* Internal table and work area (header structure)
DATA: gt_sal_employee_invocies TYPE ztt_sal_employee_invocies_mau,    " Invoices table used by screen 0200
      gv_selected_pernr        TYPE persno,
      gv_selected_sname        TYPE string,
      gv_begda                 TYPE datum,
      gv_endda                 TYPE datum,

      ok_code                  TYPE sy-ucomm,
      save_ok                  TYPE sy-ucomm.


*Objects for screen 100
DATA: gr_container_100 TYPE REF TO cl_gui_custom_container,
      gr_grid_100      TYPE REF TO cl_gui_alv_grid.

*Objects for screen 200
DATA: gr_container_200 TYPE REF TO cl_gui_custom_container,
      gr_salv_200      TYPE REF TO cl_salv_table.

*Service, and DB classes instances
DATA: gr_bonus_service TYPE REF TO zcl_sal_bonus_service_mau,
      gr_db            TYPE REF TO zcl_sal_bonus_db_mau.


*Class that manages navigation in the ALV report
CLASS lcl_navigation_manager DEFINITION DEFERRED.
DATA: gr_nav_manager TYPE REF TO lcl_navigation_manager.
