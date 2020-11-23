/*
 * Lisp interpreter
 */

#define SC_NONE         0
#define SC_NORMAL       1

#define TYPE_ERR   -1
#define TYPE_ATOM   1
#define TYPE_LIST   2
#define TYPE_LAMBDA 3
#define TYPE_LABEL  4

#define ERR_PAIRBRACKET    1
#define ERR_WRONGSTARTCHAR 2
#define ERR_PAIRQUOTE      3
#define ERR_BRA_EXPECTED   4
#define ERR_LIST_EXPECTED  5
#define ERR_ATOM_EXPECTED  6
#define ERR_LOGIC_EXPECTED 7
#define ERR_LAMBDA_EXPECTED 8
#define ERR_WRONG_PARAM_NUMBER 9
#define ERR_UNKNOWN_FUNCTION 10
#define ERR_WRONG_LIST_LENGTH 11

//#define __LOGGING__

STATIC cFalse := "()", cTrue := "t"
STATIC nLispErr := 0
STATIC aErrtxt := { "Pair bracket not found", "Wrong char in a line start", "Pair quote not found", ;
   "Left bracket expected", "List expected", "Atom expected", "Logical value expected", ;
   "Lanbda expected", "Wrong number of parameters", "Unknown function", "Wrong list length" }
STATIC aLabels, aDefuns, nParamGlob
STATIC aGlobVars
STATIC aFuncsHb
STATIC cError := ""
STATIC nEvalLevel

FUNCTION lisp_Run()
   RETURN Nil

FUNCTION lisp_Eval( xText, lLoad )

   LOCAL s, cEol := Chr(10), i, nPos, c, nLevel, cBuff, xRes
   LOCAL lIn := .F., lNeedNext

   IF Empty( lLoad )
      aLabels := {}
      aDefuns := hb_Hash()
      nParamGlob := 0
      aGlobVars := hb_Hash()
      aFuncsHb  := hb_Hash()
   ENDIF

   IF Valtype( xText ) == "C"
      IF '(' $ xText
         xText := { xText }
      ELSEIF File( xText )
         xText := MemoRead( xText )
         IF ( i := At( cEol, xText ) ) > 1 .AND. Substr( xText, i-1, 1 ) == Chr(13)
            cEol := Chr(13) + cEol
         ENDIF
         xText := hb_ATokens( xText, cEol )
      ENDIF
   ENDIF

   IF Empty( lLoad )
      SetCursor( SC_NORMAL )
   ENDIF
   FOR i := 1 TO Len( xText )
      s := xText[i]
      lNeedNext := .F.
      DO WHILE .T.
         IF lNeedNext
            EXIT
         ENDIF
         nPos := cedi_StrSkipChars( s, 1 )
         IF nPos > Len( s ) .OR. ( c := Substr( s, nPos, 1 ) ) == ';'
            lNeedNext := .T.
            LOOP
         ENDIF
         IF lIn
            IF ( nPos := lisp_GetPairBracket( s, nPos, @nLevel ) ) < 0
               IF i == Len( xText )
                  lisp_ShowError( aErrTxt[ERR_PAIRBRACKET] )
                  RETURN Nil
               ENDIF
               cBuff += AllTrim( s ) + " "
               lNeedNext := .T.
               LOOP
            ENDIF
         ELSE
            IF c == '('
               nLevel := 0
               cBuff := ""
               IF ( nPos := lisp_GetPairBracket( s, nPos, @nLevel ) ) < 0
                  IF i == Len( xText )
                     lisp_ShowError( aErrTxt[ERR_PAIRBRACKET] )
                     RETURN Nil
                  ENDIF
                  lIn := .T.
                  cBuff += AllTrim( s ) + " "
                  lNeedNext := .T.
                  LOOP
               ENDIF
            ELSE
               lisp_ShowError( aErrTxt[ERR_WRONGSTARTCHAR] )
               ? Substr( s, nPos, 1 )
               RETURN Nil
            ENDIF
         ENDIF

         lIn := .F.
         cBuff += LTrim( Left( s, nPos ) )
         //edi_Writelog( "- Parse line -" )
         //edi_Writelog( cBuff )
         cBuff := lisp_Lambda_1( cBuff, .T. )
         //edi_Writelog( cBuff )
         //edi_Writelog( "- Eval line -" )
         nEvalLevel := 0
         IF Valtype( xRes := lisp_EvalExpr( cBuff ) ) != "A" .AND. Empty( lLoad )
            ? xRes
         ENDIF
         lisp_ShowError()

         IF Empty ( s := AllTrim( Substr( s, nPos+1 ) ) )
            EXIT
         ENDIF
      ENDDO
   NEXT
   IF Empty( lLoad )
      SetCursor( SC_NONE )
   ENDIF

   RETURN Nil

STATIC FUNCTION lisp_GetPairBracket( s, n, nLevel )

   LOCAL c

   DO WHILE ( n := cedi_strpbrk( '"()', s, n ) ) > 0
      IF ( c := Substr( s, n, 1 ) ) == '"'
         IF ( n := hb_At( '"', s, n + 1 ) ) == 0
            RETURN -2
         ENDIF
      ELSEIF c == '('
         nLevel ++
      ELSEIF c == ')'
         nLevel --
         IF nLevel == 0
            RETURN n
         ENDIF
      ENDIF
      n ++
   ENDDO

   RETURN -1

STATIC FUNCTION lisp_Error( nError, s )

   IF !Empty( nError )
     nLispErr := nError
   ENDIF
   IF !Empty( s )
      cError += s + Chr(10)
   ENDIF
#ifdef __LOGGING__
   nEvalLevel --
#endif

   RETURN TYPE_ERR

STATIC FUNCTION lisp_ShowError( s )

   LOCAL nSkip := 0, cLine

   IF Empty( s ) .AND. nLispErr > 0
      s := aErrtxt[nLispErr]
   ENDIF
   IF !Empty( s )
      ? "Error:", s
   ENDIF
   IF !Empty( cError )
      DO WHILE !Empty( cLine := hb_TokenPtr( cError, @nSkip, Chr(10) ) )
         ? cLine
      ENDDO
   ENDIF
   cError := ""

   RETURN Nil

FUNCTION lisp_EvalExpr( s, nType )

   LOCAL nPos, nPos2, cmd, nGetType, nGetType2, cNext, cExpr, cRes, nLen, l, n, c
   LOCAL aLambda, cName

#ifdef __LOGGING__
   edi_Writelog( Space(nEvalLevel*2) + "E>" + s )
   nEvalLevel ++
#endif
   nLispErr := 0
   nPos := cedi_strSkipChars( s, 2 )
   IF Left( s, 1 ) == "'"
      cNext := lisp_GetNextExpr( s, nPos )
      IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
      nType := Iif( Left( cNext,1 ) $ "('" .AND. !(cNext == cFalse), TYPE_LIST, TYPE_ATOM )
      RETURN lisp_EvalRet( cNext )

   ELSEIF Substr( s, nPos, 1 ) == '('
      cNext := lisp_GetNextExpr( s, @nPos )
      IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
      cNext := lisp_EvalExpr( cNext, @nGetType )
      IF nGetType == TYPE_LAMBDA .OR. nGetType == TYPE_LABEL
         // Evaluate function: ((lambda... or ((label...
         cName := cNext[2]
         cExpr := lisp_EvalLambda( cNext, s, nPos, @nGetType )
         nType := nGetType
         IF ( nPos := Ascan( aLabels, {|a|a[1]==cName} ) ) > 0
            hb_ADel( aLabels, nPos, .T. )
         ENDIF
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         RETURN lisp_EvalRet( cExpr )
      ELSE
      ENDIF

   ELSEIF Substr( s, nPos, 1 ) == ')'
      nType := TYPE_ATOM
      RETURN lisp_EvalRet( cFalse )
   ELSE
      cmd := Lower( lisp_GetNextExpr( s, @nPos ) )
      n := nPos
      cNext := lisp_GetNextExpr( s, @nPos )
      IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF

      IF Asc(cmd) == 99 .AND. Right(cmd,1) == "r" .AND. ( nLen := Len(cmd) ) >= 3 .AND. ;
         hb_strReplace( cmd, "ad" ) == "cr"
         // car, cdr, ...
         IF Left( cNext,1 ) $ "('"
            cNext := lisp_EvalExpr( cNext, @nType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            IF nType == TYPE_LIST
               DO WHILE --nLen > 1
                  IF Substr( cmd,nLen,1 ) == "a"
                     cNext := lisp_getCar( cNext, @nType )
                     IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                  ELSE
                     cNext := lisp_getCdr( cNext, @nType )
                     IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                     IF cNext == cFalse
                        nType := TYPE_ATOM
                        RETURN lisp_EvalRet( cFalse )
                     ENDIF
                  ENDIF
               ENDDO
               RETURN lisp_EvalRet( cNext )
            ELSEIF cNext == cFalse
               nType := TYPE_ATOM
               RETURN lisp_EvalRet( cFalse )
            ELSE
               nType := lisp_Error( ERR_LIST_EXPECTED,s); RETURN Nil
            ENDIF
         ELSE
            nType := lisp_Error( ERR_BRA_EXPECTED,s ); RETURN Nil
         ENDIF
      ENDIF

      SWITCH cmd
      CASE "quote"
         nType := Iif( Left( cNext,1 ) $ "('" .AND. !(cNext == cFalse), TYPE_LIST, TYPE_ATOM )
         RETURN lisp_EvalRet( cNext )

      CASE "atom"
         nType := TYPE_ATOM
         IF Left( cNext,1 ) $ "('"
            lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            RETURN lisp_EvalRet( Iif( nGetType == TYPE_ATOM, cTrue, cFalse ) )
         ELSE
            RETURN lisp_EvalRet( cTrue )
         ENDIF

      CASE "cond"
         DO WHILE .T.
            nPos2 := 2
            cExpr := lisp_GetNextExpr( cNext, @nPos2 )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF

            IF cExpr == cTrue .OR. ( cRes := lisp_EvalExpr( cExpr, @nType ) ) == cTrue
               cExpr := lisp_GetNextExpr( cNext, @nPos2 )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
               cRes := lisp_EvalExpr( cExpr, @nType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
               RETURN lisp_EvalRet( cRes )
            ELSEIF cRes != cFalse
               nType := lisp_Error( ERR_LOGIC_EXPECTED,cExpr+Chr(10)+s ); RETURN Nil
            ENDIF
            IF Empty( cNext := lisp_GetNextExpr( s, @nPos ) )
               EXIT
            ENDIF
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDDO
         nType := TYPE_ATOM
         RETURN lisp_EvalRet( cFalse )

      CASE "cons"
      CASE "append"
         nType := TYPE_LIST
         IF Left( cNext,1 ) $ "('"
            cNext := lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF

         cExpr := lisp_GetNextExpr( s, @nPos )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         IF Left( cExpr,1 ) $ "('"
            cExpr := lisp_EvalExpr( cExpr, @nGetType2 )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF

         IF cmd == "cons"
            IF nGetType2 == TYPE_LIST
               RETURN lisp_EvalRet( "( " + cNext + " " + Ltrim( Substr( cExpr, 2 ) ) )
            ELSE
               RETURN lisp_EvalRet( "( " + Iif( cNext == cFalse, "", cNext ) + " " + Iif( cExpr==cFalse, "", cExpr ) + ")" )
            ENDIF
         ELSE
            IF nGetType == TYPE_LIST .OR. cNext == cFalse
               RETURN lisp_EvalRet( Trim(Left( cNext, Len(cNext)-1 )) + " " + ;
                  Iif( nGetType2 == TYPE_LIST, AllTrim( Substr(cExpr,2,Len(cExpr)-2) ) + ")", ;
                  cExpr + ")" ) )
            ELSE
               nType := lisp_Error( ERR_LIST_EXPECTED,s ); RETURN Nil
            ENDIF
         ENDIF

      CASE "eq"
      CASE "equal"
      CASE "null"
         IF Left( cNext,1 ) $ "('"
            cNext := lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF
         IF cmd == "null"
            nGetType2 := TYPE_ATOM
            cExpr := cFalse
         ELSE
            cExpr := lisp_GetNextExpr( s, @nPos )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            IF Left( cExpr,1 ) $ "('"
               cExpr := lisp_EvalExpr( cExpr, @nGetType2 )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            ENDIF
         ENDIF

         nType := TYPE_ATOM
         IF nGetType != nGetType2
            RETURN lisp_EvalRet( cFalse )
         ELSE
            RETURN lisp_EvalRet( Iif( nGetType == TYPE_LIST, ;
               Iif( StrTran(cNext," ","") == StrTran(cExpr," ",""), cTrue, cFalse ), ;
               Iif( cNext == cExpr, cTrue, cFalse ) ) )
         ENDIF

      CASE "list"
         cRes := "("
         DO WHILE !Empty( cNext )
            IF Left( cNext,1 ) $ "('"
               cNext := lisp_EvalExpr( cNext, @nGetType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            ENDIF
            cRes += cNext + " "
            cNext := lisp_GetNextExpr( s, @nPos )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDDO
         IF Len( cRes ) == 1
            nType := TYPE_ATOM
            RETURN lisp_EvalRet( cFalse )
         ELSE
            nType := TYPE_LIST
            RETURN lisp_EvalRet( cRes + ')' )
         ENDIF

      CASE "and"
         l := .T.
      CASE "or"
         l := !Empty( l )
         nType := TYPE_ATOM
         DO WHILE !Empty( cNext )
            IF Left( cNext,1 ) $ "('"
               cNext := lisp_EvalExpr( cNext, @nGetType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            ENDIF
            IF l .AND. cNext == cFalse
               RETURN lisp_EvalRet( cFalse )
            ELSEIF !l .AND. cNext == cTrue
               RETURN lisp_EvalRet( cNext )
            ENDIF
            cExpr = cNext
            cNext := lisp_GetNextExpr( s, @nPos )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDDO
         RETURN lisp_EvalRet( Iif( l, cExpr, cFalse ) )

      CASE "not"
         cNext := lisp_EvalExpr( cNext, @nGetType )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         nType := TYPE_ATOM
         RETURN lisp_EvalRet( Iif( cNext == cFalse, cTrue, cFalse ) )

      CASE "pair"
         cNext := lisp_EvalExpr( cNext, @nGetType )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF

         cExpr := lisp_GetNextExpr( s, @nPos )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         IF Left( cExpr,1 ) $ "('"
            cExpr := lisp_EvalExpr( cExpr, @nGetType2 )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF
         IF nGetType != TYPE_LIST .OR. nGetType2 != TYPE_LIST
            nType := lisp_Error( ERR_LIST_EXPECTED,s ); RETURN Nil
         ENDIF
         nPos := nPos2 := 2
         cRes := "("
         DO WHILE .T.
            cName := lisp_GetNextExpr( cNext, @nPos )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            cmd := lisp_GetNextExpr( cExpr, @nPos2 )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            IF Empty( cName ) != Empty( cmd )
               nType := lisp_Error( ERR_WRONG_LIST_LENGTH,s ); RETURN Nil
            ENDIF
            IF Empty( cName )
               EXIT
            ENDIF
            cRes += " (" + cName + " " + cmd + ")"
         ENDDO
         nType := TYPE_LIST
         RETURN lisp_EvalRet( cRes + ")" )

      CASE "set"
      CASE "setq"
         IF cmd == "set"
            cName := lisp_EvalExpr( cNext, @nGetType )
         ELSEIF Left( cNext,1 ) $ "('"
            nType := lisp_Error( ERR_ATOM_EXPECTED,s ); RETURN Nil
         ELSE
            cName := cNext
         ENDIF
         cExpr := lisp_GetNextExpr( s, @nPos )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         IF Left( cExpr,1 ) $ "('"
            cExpr := lisp_EvalExpr( cExpr, @nGetType2 )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF
         aGlobVars[cName] := cExpr
         RETURN Lisp_EvalRet( cExpr )

      CASE "length"
         n := 0
         DO WHILE !Empty( cNext )
            n ++
            cNext := lisp_GetNextExpr( s, @nPos )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDDO
         RETURN lisp_EvalRet( Ltrim( Str( n ) ) )

      CASE "+"
         l := .T.
      CASE "*"
         l := !Empty( l )
         nType := TYPE_ATOM
         n := Iif( l, 0, 1 )
         DO WHILE !Empty( cNext )
            IF Left( cNext,1 ) $ "('"
               cNext := lisp_EvalExpr( cNext, @nGetType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            ENDIF
            IF l
               n += Val( cNext )
            ELSE
               n *= Val( cNext )
            ENDIF
            cNext := lisp_GetNextExpr( s, @nPos )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDDO
         RETURN lisp_EvalRet( Ltrim( Str( n ) ) )

      CASE "max"
         l := .T.
      CASE "min"
         l := !Empty( l )
         nType := TYPE_ATOM
         n := Nil
         DO WHILE !Empty( cNext )
            IF Left( cNext,1 ) $ "('"
               cNext := lisp_EvalExpr( cNext, @nGetType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            ENDIF
            cNext := Val( cNext )
            IF l
               n := Iif( n == Nil, cNext, Max( n, cNext ) )
            ELSE
               n := Iif( n == Nil, cNext, Min( n, cNext ) )
            ENDIF
            cNext := lisp_GetNextExpr( s, @nPos )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDDO
         RETURN lisp_EvalRet( Ltrim( Str( n ) ) )

      CASE "-"
      CASE "/"
      CASE "%"
      CASE ">"
      CASE "<"
      CASE "="
         IF Left( cNext,1 ) $ "('"
            cNext := lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF
         cExpr := lisp_GetNextExpr( s, @nPos )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         IF Left( cExpr,1 ) $ "('"
            cExpr := lisp_EvalExpr( cExpr, @nGetType2 )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF
         IF nGetType != TYPE_ATOM .OR. nGetType2 != TYPE_ATOM
            nType := lisp_Error( ERR_ATOM_EXPECTED,s ); RETURN Nil
         ENDIF
         IF cmd == "="
            RETURN lisp_EvalRet( Iif(cNext == cExpr, cTrue, cFalse ) )
         ENDIF
         cNext := Val( cNext ); cExpr := Val( cExpr )
         SWITCH cmd
         CASE "-"
            RETURN lisp_EvalRet( Ltrim(Str( cNext - cExpr )) )
         CASE "/"
            RETURN lisp_EvalRet( Ltrim(Str( Int(cNext / cExpr) )) )
         CASE "%"
            RETURN lisp_EvalRet( Ltrim(Str( cNext % cExpr )) )
         CASE ">"
            RETURN lisp_EvalRet( Iif(cNext > cExpr, cTrue, cFalse ) )
         CASE "<"
            RETURN lisp_EvalRet( Iif(cNext < cExpr, cTrue, cFalse ) )
         ENDSWITCH

      CASE "lambda"
         aLambda := lisp_Lambda( s, nPos, cNext )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         nType := TYPE_LAMBDA
         RETURN aLambda

      CASE "numberp"
         IF Left( cNext,1 ) $ "('"
            cNext := lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         ENDIF
         RETURN lisp_evalRet( Iif( IsDigit(cNext), cTrue, cFalse ) )

      CASE "label"
         IF Left( cNext,1 ) $ "('"
            nType := lisp_Error( ERR_ATOM_EXPECTED,s ); RETURN Nil
         ELSE
            cName := cNext
         ENDIF
         cNext := lisp_GetNextExpr( s, @nPos )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         IF Left( cNext,1 ) == "(" .AND. !Empty( aLambda := lisp_EvalExpr( cNext, @nGetType ) ) ;
            .AND. nGetType == TYPE_LAMBDA
            Aadd( aLabels, { cName, aLambda } )
            aLambda[2] := cName
            nType := TYPE_LABEL
            RETURN aLambda
         ELSE
            nType := lisp_Error( ERR_LAMBDA_EXPECTED,s ); RETURN Nil
         ENDIF

      CASE "defun"
         IF Left( cNext,1 ) $ "('"
            nType := lisp_Error( ERR_ATOM_EXPECTED,s ); RETURN Nil
         ELSE
            cName := cNext
         ENDIF
         cNext := lisp_GetNextExpr( s, @nPos )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF

         //edi_Writelog( "defun: " + cName )
         aLambda := lisp_Lambda( s, nPos, cNext, cName )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         aDefuns[aLambda[2]] := aLambda
         nType := TYPE_LABEL
         RETURN aLambda

      CASE "defunhb"

         cExpr := lisp_GetNextExpr( s, @nPos )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         aFuncsHb[cNext] := cExpr

         RETURN lisp_Evalret( cTrue )

      CASE "load"
         IF File( cNext )
            lisp_Eval( cNext, .T. )
            RETURN lisp_EvalRet( cTrue )
         ELSE
            RETURN lisp_EvalRet( cFalse )
         ENDIF

      OTHERWISE
         IF ( nPos2 := Ascan( aLabels, {|a|a[1]==cmd} ) ) > 0
            cExpr := lisp_EvalLambda( aLabels[nPos2,2], s, n, @nGetType )
            nType := nGetType
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            RETURN lisp_EvalRet( cExpr )
         ELSEIF !Empty( aLambda := hb_hGetDef( aDefuns, cmd, Nil ) )
            cExpr := lisp_EvalLambda( aLambda, s, n, @nGetType )
            nType := nGetType
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            RETURN lisp_EvalRet( cExpr )
         ELSEIF !Empty( cName := hb_hGetDef( aFuncsHb, cmd, Nil ) )
            cRes := ""
            n := 0
            DO WHILE !Empty( cNext )
               IF Left( cNext,1 ) $ "('"
                  cNext := lisp_EvalExpr( cNext, @nGetType )
                  IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
               ENDIF
               n ++
               cRes += Iif( n > 1, ",", "" ) + Iif( ( c := Substr(cName,n,1) ) == "N", cNext, ;
                  Iif( c == "L", Iif( cNext == cTrue, ".T.", ".F." ), '"'+cNext+'"' ) )
               cNext := lisp_GetNextExpr( s, @nPos )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            ENDDO
            cRes := &( cmd + "(" + cRes + ")" )
            RETURN lisp_EvalRet( Iif( (c := Valtype(cRes)) == "N", Ltrim(Str(cRes)), ;
               Iif( c == "L", Iif( cRes, cTrue, cFalse ), cRes ) ) )
         ELSE
            nType := lisp_Error( ERR_UNKNOWN_FUNCTION, cmd+Chr(10)+s ); RETURN Nil
         ENDIF
      ENDSWITCH
   ENDIF

   RETURN Nil

STATIC FUNCTION lisp_getCar( cNext, nType )

   IF Left( cNext,1 ) == "'"
      nType := TYPE_ATOM
      RETURN "quote"
   ENDIF

   cNext := lisp_GetNextExpr( cNext, 2 )
   IF nLispErr > 0; RETURN Nil; ENDIF

   nType := Iif( Left( cNext,1 ) $ "('", TYPE_LIST, TYPE_ATOM )
   RETURN cNext

STATIC FUNCTION lisp_getCdr( cNext, nType )

   LOCAL nPos := 2

   IF Left( cNext,1 ) == "'"
      cNext := lisp_GetNextExpr( cNext, 2 )
      IF nLispErr > 0; RETURN Nil; ENDIF

      nType := TYPE_LIST
      RETURN "(" + cNext + ")"
   ENDIF

   lisp_GetNextExpr( cNext, @nPos )
   IF nLispErr > 0; RETURN Nil; ENDIF

   cNext := '(' + Substr( cNext, nPos )
   nPos := cedi_strSkipChars( cNext, 2 )
   IF Substr( cNext, nPos, 1 ) == ')'
      nType := TYPE_ATOM
      RETURN cFalse
   ENDIF

   nType := TYPE_LIST
   RETURN cNext

STATIC FUNCTION lisp_EvalRet( s )

#ifdef __LOGGING__
   nEvalLevel --
   edi_Writelog( Space(nEvalLevel*2) + "R>" + Iif( Valtype(s) == "C", s, "<<"+Valtype(s)+">>" ) )
#endif
   RETURN s

STATIC FUNCTION lisp_Lambda( s, nPos, cBody, cName )

   LOCAL aLambda, nPos2 := 2

   IF Left( cBody,1 ) == "("
      aLambda := { lisp_GetNextExpr( s, @nPos ), cName }
      IF nLispErr > 0; lisp_Error( ,s ); RETURN Nil; ENDIF

      DO WHILE !Empty( cName := lisp_GetNextExpr( cBody, @nPos2 ) )
         Aadd( aLambda, cName )
      ENDDO
   ELSE
      lisp_Error( ERR_BRA_EXPECTED,cBody ); RETURN Nil
   ENDIF

   RETURN aLambda

STATIC FUNCTION lisp_Lambda_1( s, lStart )

   LOCAL nPos, nPos1, nPos2 := 1, nFromEnd, cName, cNewName, s1, s2

   //edi_Writelog( "ll1> " + s )
   IF !lStart
      nPos2 := hb_At( ')', s, 6 ) + 1
   ENDIF
   DO WHILE .T.
      nPos := hb_At( "lambda ", s, nPos2 )
      nPos1 := hb_At( "defun ", s, nPos2 )
      IF nPos > 0 .OR. nPos1 > 0
         nPos := Iif( nPos > 0 .AND. nPos1 > 0, Min( nPos, nPos1 ), Iif( nPos > 0, nPos, nPos1 ) )
         nPos := cedi_strSkipChars( s, nPos-1, .T. )
         IF Substr( s, nPos, 1 ) == '(' .AND. ( nPos2 := lisp_GetPairBracket( s, nPos, 0 ) ) > 0
            nFromEnd := Len( s ) - nPos2
            s := Left( s, nPos-1 ) + lisp_Lambda_1( SubStr( s, nPos, nPos2-nPos+1 ), .F. ) + Substr( s, nPos2+1 )
            nPos2 := Len( s ) - nFromEnd
         ELSE
            nPos2 := nPos + 6
         ENDIF
      ELSE
         EXIT
      ENDIF
   ENDDO
   IF lStart
      /*
      nPos := 1
      DO WHILE ( nPos := hb_At( "quote ", s, nPos ) ) > 0
         nPos1 := nPos + 6
         nPos := cedi_strSkipChars( s, nPos-1, .T. )
         IF Substr( s, nPos, 1 ) == '(' .AND. ( nPos2 := lisp_GetPairBracket( s, nPos, 0 ) ) > 0
            nPos1 := cedi_strSkipChars( s, nPos1 )
            s := Left( s, nPos-1 ) + "'" + Substr( s, nPos1, nPos2-nPos1 ) + Substr( s, nPos2+1 )
         ENDIF
      ENDDO
      */
   ELSE
      nPos := nPos1 := hb_At( '(', s, 6 )
      nPos ++
      cName := lisp_GetNextExpr( s, @nPos )
      IF !Empty( cName )
         nPos2 := hb_At( ')', s, nPos ) + 1
         s1 := Substr( s, nPos2 )
         s2 := ""
         DO WHILE !Empty( cName )
            cNewName := '_' + Ltrim(Str(++nParamGlob)) + '_'
            s2 += cNewName + " "

            s1 := hb_strReplace( s1, { ' '+cName+' ', '('+cName+' ', ;
               ' '+cName+')', '('+cName+')' }, { ' '+cNewName+' ', '('+cNewName+' ', ;
               ' '+cNewName+')', '('+cNewName+')' } )

            cName := lisp_GetNextExpr( s, @nPos )
         ENDDO
         s := Left( s, nPos1 ) + s2 + ")" + s1
      ENDIF
   ENDIF

   //edi_Writelog( "ll2> " + s )
   RETURN s

STATIC FUNCTION lisp_EvalLambda( aLambda, s, nPos, nType )

   LOCAL cExpr := aLambda[1], i, cParam, nGetType

   i := 2
   //edi_Writelog( "EvalLambda: " + Iif( aLambda[2]==Nil,"",aLambda[2] ) + " " + Ltrim(Str(Len(aLambda))) )
   //edi_Writelog( "0>" + aLambda[1] )
   //edi_Writelog( "s>" + s )
   //edi_Writelog( "n>" + Str(nPos) )
   DO WHILE !Empty( cParam := lisp_GetNextExpr( s, @nPos ) )
      //edi_Writelog( "p"+Ltrim(Str(i-1))+">" + cParam )
      i ++
      IF i > Len( aLambda )
         lisp_Error( ERR_WRONG_PARAM_NUMBER,aLambda[1] ); RETURN Nil
      ENDIF
      IF Left( cParam, 1 ) == "("
         cParam := "'" + lisp_EvalExpr( cParam )
      ENDIF
      cExpr := StrTran( cExpr, aLambda[i], cParam )
   ENDDO
   IF i != Len( aLambda )
      lisp_Error( ERR_WRONG_PARAM_NUMBER,aLambda[1] ); RETURN Nil
   ENDIF

   //edi_Writelog( "1>" + aLambda[1] )
   //edi_Writelog( "2>" + cExpr )
   cExpr := lisp_EvalExpr( cExpr, @nGetType )
   IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
   nType := nGetType
   //edi_Writelog( "3>" + cExpr )

   RETURN cExpr

STATIC FUNCTION lisp_GetNextExpr( s, nPos )

   LOCAL c, nPos2, n

   nPos := cedi_strSkipChars( s, nPos )
   IF ( c := Substr( s, nPos, 1 ) ) == '('
      IF ( nPos2 := lisp_GetPairBracket( s, nPos, 0 ) ) < 0
         lisp_Error( ERR_PAIRBRACKET, SubStr(s,nPos) )
         RETURN ""
      ENDIF
      nPos2 ++
      s := Substr( s, nPos, nPos2-nPos )
      nPos := nPos2
      RETURN s

   ELSEIF c == '"'
      IF ( nPos2 := hb_At( '"', s, nPos+1 ) ) == 0
         lisp_Error( ERR_PAIRQUOTE, SubStr(s,nPos) )
         RETURN ""
      ELSE
         nPos2 ++
         s := Substr( s, nPos, nPos2-nPos )
         nPos := nPos2
         RETURN s
      ENDIF

   ELSEIF c == "'"
      nPos ++
      s := lisp_GetNextExpr( s, @nPos )
      RETURN "'" + s

   ELSEIF c == ')'
      RETURN ""

   ELSE
      nPos2 := cedi_strPBrk( " )", s, nPos+1 )
      IF nPos2 < 0
         s := Substr( s, nPos )
         nPos2 := Len( s ) + 1
         n := nPos2 - nPos
      ELSE
         s := Substr( s, nPos, n := (nPos2-nPos) )
      ENDIF
      nPos := nPos2
      RETURN Iif( n == 3 .AND. Lower(s) == "nil", cFalse, ;
         Iif( ( c := hb_hGetDef( aGlobVars, s, Nil ) ) != Nil, c, s ) )
   ENDIF

   RETURN ""
