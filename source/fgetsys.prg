/*
 * A replacement for a GET system, which respects the utf8.
 *
 * Copyright 2019 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
 */

#include "inkey.ch"
#include "setcurs.ch"
#include "hbgtinfo.ch"

#define G_Y      1
#define G_X      2
#define G_TYPE   3
#define G_VALUE  4
#define G_WIDTH  5
#define G_CLR    6
#define G_CLRSEL 7
#define G_CB     8
#define G_GROUP  9

#define G2_OPT   1
#define G2_FIRST 2

#define G_TYPE_STRING  0
#define G_TYPE_CHECK   1
#define G_TYPE_BUTTON  2
#define G_TYPE_RADIO   3

#define SHIFT_PRESSED 0x010000
#define CTRL_PRESSED  0x020000

STATIC aClrdef
STATIC iChoic

FUNCTION edi_READ( aGets, pKeys )

   LOCAL nCurr := 1, i, j, nKeyExt, nKey, nRes := 0, nCol, nRow, nx, x, y, s, nLen, xr
   LOCAL clrdef := SetColor(), lUtf8 := ( Lower(hb_cdpSelect()) == "utf8" )
   LOCAL aOpt := Array( Len( aGets ), 2 )
   LOCAL nCursOld := SetCursor()

   aClrdef := hb_aTokens( clrdef, ',' )
   IF aClrdef[4] == "N/N"
      aClrdef[4] := ""
   ENDIF
   FOR i := 1 TO Len( aGets )
      aOpt[i,G2_OPT] := .T.
      aOpt[i,G2_FIRST] := 1
      IF aGets[i,G_TYPE] >= 0
         ShowGetItem( aGets[i], .F., lUtf8,, aOpt[i] )
      ENDIF
   NEXT

   DO WHILE aGets[nCurr,G_TYPE] < 0
      nCurr ++
   ENDDO
   ShowGetItem( aGets[nCurr], .T., lUtf8, .T., aOpt[nCurr] )

   DO WHILE .T.
      nKeyExt := Inkey( 0, HB_INKEY_ALL + HB_INKEY_EXT )
      nKey := hb_keyStd( nKeyExt )
      IF pKeys != Nil .AND. hb_hHaskey( pKeys, nKeyExt )
         KEYBOARD pKeys[nKeyExt]
         LOOP
      ENDIF
      nx := Col()
      y := Row()
      x := nx - aGets[nCurr,G_X] + 1
      xr := x + aOpt[nCurr,G2_FIRST] - 1

      IF ( nKey >= K_SPACE .AND. nKey <= 255 ) .OR. ( lUtf8 .AND. nKey > 3000 )
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
            IF aOpt[nCurr,G2_OPT]
               nx := aGets[nCurr,G_X]
               x := 1
               aGets[nCurr,G_VALUE] := ""
               aOpt[nCurr,G2_OPT] := .F.
            ENDIF
            aGets[nCurr,G_VALUE] := cp_Left( lUtf8,aGets[nCurr,G_VALUE],xr-1 ) + ;
                  cp_Chr( lUtf8,nKey ) + cp_Substr( lUtf8,aGets[nCurr,G_VALUE],xr )
            Scroll( y, aGets[nCurr,G_X], y, aGets[nCurr,G_X] + aGets[nCurr,G_WIDTH] - 1 )
            DevPos( y, aGets[nCurr,G_X] )
            IF x < aGets[nCurr,G_WIDTH]
               IF cp_Len( lUtf8, aGets[nCurr,G_VALUE] ) < aGets[nCurr,G_WIDTH]
                  DevOut( aGets[nCurr,G_VALUE] )
               ELSE
                  DevOut( cp_Substr( lUtf8,aGets[nCurr,G_VALUE],aOpt[nCurr,G2_FIRST],aGets[nCurr,G_WIDTH] ) )
               ENDIF
               DevPos( y, ++nx )
            ELSE
               aOpt[nCurr,G2_FIRST]++
               DevOut( cp_Substr( lUtf8,aGets[nCurr,G_VALUE],aOpt[nCurr,G2_FIRST],aGets[nCurr,G_WIDTH] ) )
               DevPos( y, nx )
            ENDIF
         ELSEIF aGets[nCurr,G_TYPE] == G_TYPE_CHECK .OR. aGets[nCurr,G_TYPE] == G_TYPE_RADIO
            IF nKey == K_SPACE
               IF aGets[nCurr,G_TYPE] == G_TYPE_CHECK .OR. ;
                  ( aGets[nCurr,G_TYPE] == G_TYPE_RADIO .AND. !aGets[nCurr,G_VALUE] )
                  aGets[nCurr,G_VALUE] := !aGets[nCurr,G_VALUE]
                  DevPos( y, aGets[nCurr,G_X] )
                  DevOut( Iif( aGets[nCurr,G_VALUE], "x"," " ) )
                  IF aGets[nCurr,G_TYPE] == G_TYPE_RADIO
                     FOR i := 1 TO Len( aGets )
                        IF i != nCurr .AND. aGets[i,G_TYPE] == G_TYPE_RADIO .AND. ;
                              (Len(aGets[i]) < G_GROUP .OR. aGets[i,G_GROUP] == aGets[nCUrr,G_GROUP])
                           aGets[i,G_VALUE] := .F.
                           DevPos( y, aGets[i,G_X] )
                           DevOut( " " )
                        ENDIF
                     NEXT
                  ENDIF
                  DevPos( y, aGets[nCurr,G_X] )
               ENDIF
            ENDIF
         ELSEIF aGets[nCurr,G_TYPE] == G_TYPE_BUTTON
            IF nKey == K_SPACE
               IF Len(aGets[nCurr]) >= G_CB .AND. !Empty(aGets[nCurr,G_CB])
                  Eval( aGets[nCurr,G_CB] )
                  ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
               ENDIF
            ENDIF
         ENDIF

      ELSEIF nKey == K_DEL
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
            aOpt[nCurr,G2_OPT] := .F.
            IF x <= cp_Len( lUtf8, aGets[nCurr,G_VALUE] )
               aGets[nCurr,G_VALUE] := cp_Left( lUtf8, aGets[nCurr,G_VALUE], x-1 ) + ;
                  cp_Substr( lUtf8, aGets[nCurr,G_VALUE], x+1 )
               ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
               DevPos( y, nx )
            ENDIF
         ENDIF

      ELSEIF nKey == K_BS
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
            IF x > 1
               aOpt[nCurr,G2_OPT] := .F.
               aGets[nCurr,G_VALUE] := cp_Left( lUtf8, aGets[nCurr,G_VALUE], x-2 ) + ;
                  cp_Substr( lUtf8, aGets[nCurr,G_VALUE], x )
               ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
               DevPos( y, --nx )
            ENDIF
         ENDIF

      ELSEIF nKey == K_LEFT
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
            IF nx > aGets[nCurr,G_X]
               IF aOpt[nCurr,G2_OPT]
                  aOpt[nCurr,G2_OPT] := .F.
                  ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
               ENDIF
               DevPos( Row(), --nx )
            ELSEIF aOpt[nCurr,G2_FIRST] > 1
               aOpt[nCurr,G2_FIRST] --
               aOpt[nCurr,G2_OPT] := .F.
               ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
               DevPos( Row(), nx )
            ENDIF
         ELSE
            __Keyboard( Chr(K_UP) )
         ENDIF

      ELSEIF nKey == K_RIGHT
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
            IF xr < cp_Len( lUtf8, aGets[nCurr,G_VALUE] )
               IF xr < aGets[nCurr,G_WIDTH]
                  IF aOpt[nCurr,G2_OPT]
                     aOpt[nCurr,G2_OPT] := .F.
                     ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
                  ENDIF
                  DevPos( Row(), ++nx )
               ELSE
                  aOpt[nCurr,G2_FIRST] ++
                  aOpt[nCurr,G2_OPT] := .F.
                  ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
                  DevPos( Row(), nx )
               ENDIF
            ENDIF
         ELSE
            __Keyboard( Chr(K_DOWN) )
         ENDIF

      ELSEIF nKey == K_UP
         i := nCurr
         DO WHILE i > 1
            i --
            IF aGets[i,G_TYPE] >= 0
               ShowGetItem( aGets[nCurr], .F., lUtf8,, aOpt[nCurr] )
               nCurr := i
               ShowGetItem( aGets[nCurr], .T., lUtf8, aOpt[nCurr,G2_OPT], aOpt[nCurr] )
               EXIT
            ENDIF
         ENDDO

      ELSEIF nKey == K_DOWN .OR. nKey == K_TAB
         i := nCurr
         DO WHILE i < Len( aGets )
            i ++
            IF aGets[i,G_TYPE] >= 0
               ShowGetItem( aGets[nCurr], .F., lUtf8,, aOpt[nCurr] )
               nCurr := i
               ShowGetItem( aGets[nCurr], .T., lUtf8, aOpt[nCurr,G2_OPT], aOpt[nCurr] )
               EXIT
            ENDIF
         ENDDO

      ELSEIF nKey == K_CTRL_HOME
         i := 1
         DO WHILE i < Len( aGets )
            IF aGets[i,G_TYPE] >= 0
               ShowGetItem( aGets[nCurr], .F., lUtf8,, aOpt[nCurr] )
               nCurr := i
               ShowGetItem( aGets[nCurr], .T., lUtf8, aOpt[nCurr,G2_OPT], aOpt[nCurr] )
               EXIT
            ENDIF
            i ++
         ENDDO

      ELSEIF nKey == K_CTRL_END
         i := Len( aGets )
         DO WHILE i > 0
            IF aGets[i,G_TYPE] >= 0
               ShowGetItem( aGets[nCurr], .F., lUtf8,, aOpt[nCurr] )
               nCurr := i
               ShowGetItem( aGets[nCurr], .T., lUtf8, aOpt[nCurr,G2_OPT], aOpt[nCurr] )
               EXIT
            ENDIF
            i --
         ENDDO

      ELSEIF nKey == K_HOME
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
               IF aOpt[nCurr,G2_OPT] .OR. aOpt[nCurr,G2_FIRST] > 1
                  aOpt[nCurr,G2_FIRST] := 1
                  aOpt[nCurr,G2_OPT] := .F.
                  ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
               ENDIF
               DevPos( y, nx := aGets[nCurr,G_X] )
         ENDIF

      ELSEIF nKey == K_END
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
            nLen := cp_Len( lUtf8, aGets[nCurr,G_VALUE] )
            IF nLen >= aGets[nCurr,G_WIDTH]
               aOpt[nCurr,G2_FIRST] := nLen - aGets[nCurr,G_WIDTH] + 2
            ENDIF
            IF aOpt[nCurr,G2_OPT] .OR. aOpt[nCurr,G2_FIRST] > 1
               aOpt[nCurr,G2_OPT] := .F.
               ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
            ENDIF
            DevPos( y, nx := ( aGets[nCurr,G_X] + cp_Len( lUtf8, ;
               aGets[nCurr,G_VALUE] ) - aOpt[nCurr,G2_FIRST] + 1 ) )
            aOpt[nCurr,G2_OPT] := .F.
         ENDIF

      ELSEIF (hb_BitAnd( nKeyExt, CTRL_PRESSED ) != 0 .AND. nKey == 22) .OR. ;
         ( hb_BitAnd( nKeyExt, SHIFT_PRESSED ) != 0 .AND. nKey == K_INS )
         IF aGets[nCurr,G_TYPE] == G_TYPE_STRING
            IF aOpt[nCurr,G2_OPT]
               nx := aGets[nCurr,G_X]
               x := 1
               aGets[nCurr,G_VALUE] := ""
               aOpt[nCurr,G2_OPT] := .F.
            ENDIF
            s := s_cb2t() //hb_gtInfo( HB_GTI_CLIPBOARDDATA )
            aGets[nCurr,G_VALUE] := cp_Left( lUtf8,aGets[nCurr,G_VALUE],x-1 ) + ;
                  s + cp_Substr( lUtf8,aGets[nCurr,G_VALUE],x )
            DevPos( y, aGets[nCurr,G_X] )
            DevOut( aGets[nCurr,G_VALUE] )
            nx += cp_Len( lUtf8, s )
            IF nx > aGets[nCurr,G_X] + aGets[nCurr,G_WIDTH] - 1
               nx := aGets[nCurr,G_X] + aGets[nCurr,G_WIDTH] - 1
            ENDIF
            DevPos( y, nx )
         ENDIF

      ELSEIF hb_BitAnd( nKeyExt, CTRL_PRESSED ) != 0 .AND. nKey == K_CTRL_DOWN ;
            .AND. hb_keyVal( nKeyExt ) == 14
         IF nCurr < Len( aGets ) .AND. aGets[nCurr+1,G_TYPE] == G_TYPE_BUTTON
            __KeyBoard( Chr(K_DOWN) + Chr(K_SPACE) )
         ENDIF

      ELSEIF nKey == K_LBUTTONDOWN
         nCol := MCol()
         nRow := MRow()
         FOR i := 1 TO Len(aGets)
            IF aGets[i,G_TYPE] >= 0 .AND. aGets[i,G_Y] == nRow .AND. ;
                  aGets[i,G_X] <= nCol .AND. aGets[i,G_X]+aGets[i,G_WIDTH] > nCol
               ShowGetItem( aGets[nCurr], .F., lUtf8,, aOpt[nCurr] )
               nCurr := i
               ShowGetItem( aGets[nCurr], .T., lUtf8, aOpt[nCurr,G2_OPT], aOpt[nCurr] )
               IF aGets[nCurr,G_TYPE] == G_TYPE_CHECK .OR. ;
                  ( aGets[nCurr,G_TYPE] == G_TYPE_RADIO .AND. !aGets[nCurr,G_VALUE] )
                  aGets[nCurr,G_VALUE] := !aGets[nCurr,G_VALUE]
                  DevPos( nRow, aGets[nCurr,G_X] )
                  DevOut( Iif( aGets[nCurr,G_VALUE], "x"," " ) )
                  IF aGets[nCurr,G_TYPE] == G_TYPE_RADIO
                     FOR j := 1 TO Len( aGets )
                        IF j != nCurr .AND. aGets[j,G_TYPE] == G_TYPE_RADIO .AND. ;
                           (Len(aGets[j]) < G_GROUP .OR. aGets[j,G_GROUP] == aGets[nCurr,G_GROUP])
                           aGets[j,G_VALUE] := .F.
                           DevPos( aGets[j,G_Y], aGets[j,G_X] )
                           DevOut( " " )
                        ENDIF
                     NEXT
                  ENDIF
                  DevPos( nRow, aGets[nCurr,G_X] )
               ELSEIF aGets[nCurr,G_TYPE] == G_TYPE_BUTTON
                  IF Len(aGets[nCurr]) >= G_CB .AND. !Empty(aGets[nCurr,G_CB])
                     Eval( aGets[nCurr,G_CB] )
                     ShowGetItem( aGets[nCurr], .T., lUtf8,, aOpt[nCurr] )
                  ENDIF
               ENDIF
            ENDIF
         NEXT

      ELSEIF nKey == K_ENTER .OR. nKey == K_PGDN
         nRes := nCurr
         EXIT

      ELSEIF nKey == K_ESC
         EXIT

      ENDIF

   ENDDO

   SetColor( clrdef )
   SetCursor( nCursOld )

   RETURN nRes

FUNCTION ShowGetItem( aGet, lSele, lUtf8, lFirst, aOpt )

   LOCAL x

   IF lFirst == Nil; lFirst := .F.; ENDIF
   IF lSele
      IF lFirst .AND. aGet[G_TYPE] == G_TYPE_STRING .AND. ;
            !Empty( aClrdef[4] ) .AND. !Empty( aGet[G_VALUE] )
         SetColor( aClrdef[4] )
      ELSE
         SetColor( Iif( Len(aGet) < G_CLRSEL .OR.Empty(aGet[G_CLRSEL]), aClrdef[2], aGet[G_CLRSEL] ) )
      ENDIF
   ELSE
      SetColor( Iif( Len(aGet) < G_CLR .OR.Empty(aGet[G_CLR]), aClrdef[5], aGet[G_CLR] ) )
   ENDIF

   Scroll( aGet[G_Y], aGet[G_X], aGet[G_Y], aGet[G_X] + aGet[G_WIDTH] - 1 )

   IF aGet[G_TYPE] == G_TYPE_STRING
      @ aGet[G_Y], aGet[G_X] SAY Iif( aGet[G_WIDTH] >= cp_Len( lUtf8,aGet[G_VALUE] ), ;
         aGet[G_VALUE], cp_Substr( lUtf8, aGet[G_VALUE], ;
         Iif( aOpt==Nil, 1, aOpt[G2_FIRST] ), aGet[G_WIDTH] ) )

   ELSEIF aGet[G_TYPE] == G_TYPE_CHECK .OR. aGet[G_TYPE] == G_TYPE_RADIO
      @ aGet[G_Y], aGet[G_X] SAY Iif(aGet[G_VALUE],"x"," ")

   ELSEIF aGet[G_TYPE] == G_TYPE_BUTTON
      x := aGet[G_X] + Int( (aGet[G_WIDTH] - cp_Len( lUtf8,aGet[G_VALUE] ))/2 )
      @ aGet[G_Y], x SAY aGet[G_VALUE]

   ENDIF

   IF lSele
      DevPos( aGet[G_Y], aGet[G_X] )
      SetCursor( Iif( aGet[G_TYPE] == G_TYPE_BUTTON, SC_NONE, SC_NORMAL ) )
      SetColor( Iif( Len(aGet) < G_CLRSEL .OR.Empty(aGet[G_CLRSEL]), aClrdef[2], aGet[G_CLRSEL] ) )
   ENDIF

   RETURN Nil

FUNCTION edi_Wait( cText, cColor )

   LOCAL oldc, cp, aText, i, nLen := 0
   STATIC cBuffScr, x1, y1 := 10, x2, y2

   IF cText == Nil
      IF !Empty( cBuffScr )
         RestScreen( y1, x1, y2, x2, cBuffScr )
         cBuffScr := Nil
      ENDIF
   ELSE
      oldc := SetColor( cColor )
      cp := hb_cdpSelect( "RU866" )
      aText := hb_aTokens( cText, ";" )
      FOR i := 1 TO Len( aText )
         nLen := Max( nLen, Len( aText[i] ) )
      NEXT
      nLen += 4

      x1 := Int( (MaxCol()-nLen)/2 )
      x2 := x1+nLen
      y2 := y1+Len(aText)+1
      cBuffScr := SaveScreen( y1, x1, y2, x2 )
      @ y1, x1, y2, x2 BOX "�Ŀ����� "
      hb_cdpSelect( cp )
      FOR i := 1 TO Len( aText )
         @ y1+i, x1 + 2 SAY aText[i]
      NEXT
      SetColor( oldc )
   ENDIF

   RETURN Nil
