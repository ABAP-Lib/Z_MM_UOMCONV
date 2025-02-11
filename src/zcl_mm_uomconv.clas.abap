CLASS zcl_mm_uomconv DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

    PUBLIC SECTION.

        INTERFACES:
            if_amdp_marker_hdb.

        CLASS-METHODS:
            convert_material_unit
                IMPORTING
                    VALUE(iv_matnr) TYPE matnr
                    VALUE(iv_source_quantity) TYPE menge_d
                    VALUE(iv_source_uom) TYPE meins
                    VALUE(iv_destination_uom) TYPE meins
                    VALUE(iv_use_fallback) TYPE abap_bool
                RETURNING
                    VALUE(rv_destination_quantity) TYPE menge_d.

    PROTECTED SECTION.
    PRIVATE SECTION.
ENDCLASS.



CLASS zcl_mm_uomconv IMPLEMENTATION.

    METHOD convert_material_unit
        BY DATABASE FUNCTION FOR HDB LANGUAGE SQLSCRIPT
        OPTIONS READ-ONLY
        USING
            marm.

        if ( iv_source_quantity = 0 ) THEN
            rv_destination_quantity = 0;
        else

            select
                SUM (
                    case
                        WHEN marm_from.umren = 0 or marm_to.umrez = 0 then 0.000
                        else
                            ROUND(
                                ( iv_source_quantity * marm_from.umrez * marm_to.umren )
                                / ( marm_from.umren * marm_to.umrez ),
                                3,
                                ROUND_HALF_EVEN
                            )
                   end ) as menge_to
            into
                rv_destination_quantity
            from
                marm as marm_from
                left outer join marm as marm_to
                on
                    marm_to.mandt   = session_context( 'CLIENT' ) and
                    marm_to.matnr   = :iv_matnr and
                    marm_to.meinh   = :iv_destination_uom
            WHERE
                marm_from.mandt = session_context( 'CLIENT' ) and
                marm_from.matnr = :iv_matnr and
                marm_from.meinh = :iv_source_uom

            ;

            if (
                iv_use_fallback = 'X' and
                (
                    rv_destination_quantity is null or
                    rv_destination_quantity = 0
                )
            ) THEN

                rv_destination_quantity = CONVERT_UNIT(
                    "QUANTITY"=>iv_source_quantity,
                    "SOURCE_UNIT_COLUMN"=>iv_source_uom,
                    "SCHEMA"=>'SAPSR3',
                    "TARGET_UNIT_COLUMN"=>iv_destination_uom,
                    "ERROR_HANDLING"=>'set to null',
                    "CLIENT"=>session_context('CLIENT')
                    )
                ;

            end if;

            if ( rv_destination_quantity is null ) THEN
                rv_destination_quantity = 0;
            end if;

        end if;

    ENDMETHOD.

ENDCLASS.
