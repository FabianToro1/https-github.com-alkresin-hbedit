/*
 * Lisp interpreter
 */

#define TYPE_ERR   -1
#define TYPE_ATOM   1
#define TYPE_LIST   2
#define TYPE_EXPR   3
#define TYPE_LAMBDA 4
#define TYPE_LABEL  5

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

STATIC cFalse := "()", cTrue := "t"
STATIC nLispErr := 0
STATIC aErrtxt := { "Pair bracket not found", "Wrong char in a line start", "Pair quote not found", ;
   "Left bracket expected", "List expected", "Atom expected", "Logical value expected", ;
   "Lanbda expected", "Wrong number of parameters", "Unknown function" }
STATIC aLabels, aDefuns, nParamGlob
STATIC cError := ""
STATIC nEvalLevel

FUNCTION lisp_Run()
   RETURN Nil

FUNCTION lisp_Eval( xText )

   LOCAL s, cEol := Chr(10), i, nPos, c, nLevel, cBuff
   LOCAL lIn := .F., lNeedNext

   aLabels := {}
   aDefuns := hb_Hash()
   nParamGlob := 0

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
         ? lisp_EvalExpr( cBuff )
         lisp_ShowError()

         IF Empty ( s := AllTrim( Substr( s, nPos+1 ) ) )
            EXIT
         ENDIF
      ENDDO
   NEXT

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
   nEvalLevel --

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

   LOCAL nPos, nPos2, cmd, nGetType, nGetType2, cNext, cExpr, cRes
   LOCAL aLambda, cName

   edi_Writelog( Space(nEvalLevel*2) + "E>" + s )
   nEvalLevel ++
   nLispErr := 0
   nPos := cedi_strSkipChars( s, 2 )
   IF Left( s, 1 ) == "'"
      cNext := lisp_GetNextExpr( s, nPos )
      IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
      nType := Iif( Left( cNext,1 ) == '(' .AND. !(cNext == cFalse), TYPE_LIST, TYPE_ATOM )
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
      nPos2 := cedi_strPBrk( " )", s, nPos+1 )
      cmd := Lower( Substr( s, nPos, nPos2-nPos ) )
      nPos := nPos2
      cNext := lisp_GetNextExpr( s, @nPos )
      IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF

      SWITCH cmd
      CASE "atom"
         nType := TYPE_ATOM
         IF Left( cNext,1 ) $ "('"
            lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            RETURN lisp_EvalRet( Iif( nGetType == TYPE_ATOM, cTrue, cFalse ) )
         ELSE
            RETURN lisp_EvalRet( cTrue )
         ENDIF

      CASE "caar"
      CASE "cadar"
      CASE "cdar"
      CASE "cddar"
      CASE "caddar"
      CASE "car"
         IF Left( cNext,1 ) $ "('"
            cNext := lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            IF nGetType == TYPE_LIST
               cNext := lisp_getCar( cNext, @nType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
               IF cmd == "car"
                  RETURN lisp_EvalRet( cNext )
               ELSEIF cmd == "caar"
                  IF nType == TYPE_LIST
                     cNext := lisp_getCar( cNext, @nType )
                     IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                     RETURN lisp_EvalRet( cNext )
                  ELSE
                     nType := lisp_Error( ERR_LIST_EXPECTED,s); RETURN Nil
                  ENDIF
               ELSE //IF cmd == "cadar" .OR. cmd == "cdar" .OR. cmd == "cddar" .OR. cmd == "caddar"
                  IF nType == TYPE_LIST
                     cNext := lisp_getCdr( cNext, @nGetType )
                     IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                     IF cNext == cFalse
                        nType := TYPE_ATOM
                        RETURN lisp_EvalRet( cFalse )
                     ELSEIF cmd == "cdar"
                        nType := TYPE_LIST
                        RETURN lisp_EvalRet( cNext )
                     ELSEIF cmd == "cddar" .OR. cmd == "caddar"
                        cNext := lisp_getCdr( cNext, @nGetType )
                        IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                        IF cNext == cFalse
                           nType := TYPE_ATOM
                           RETURN lisp_EvalRet( cFalse )
                        ELSEIF cmd == "caddar"
                           cNext := lisp_getCar( cNext, @nType )
                           IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                           RETURN lisp_EvalRet( cNext )
                        ELSE
                           nType := TYPE_LIST
                           RETURN lisp_EvalRet( cNext )
                        ENDIF
                     ELSEIF cmd == "cadar"
                        cNext := lisp_getCar( cNext, @nType )
                        IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                        RETURN lisp_EvalRet( cNext )
                     ENDIF
                  ELSE
                     nType := lisp_Error( ERR_LIST_EXPECTED,s); RETURN Nil
                  ENDIF
               ENDIF
            ELSEIF cNext == cFalse
               nType := TYPE_ATOM
               RETURN lisp_EvalRet( cFalse )
            ELSE
               nType := lisp_Error( ERR_LIST_EXPECTED,s); RETURN Nil
            ENDIF
         ELSE
            nType := lisp_Error( ERR_BRA_EXPECTED,s ); RETURN Nil
         ENDIF

      CASE "caddr"
      CASE "cadr"
      CASE "cddr"
      CASE "cdr"
         IF Left( cNext,1 ) $ "('"
            cNext := lisp_EvalExpr( cNext, @nGetType )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            IF nGetType == TYPE_LIST
               cNext := lisp_getCdr( cNext, @nGetType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                IF cNext == cFalse
                  nType := TYPE_ATOM
                  RETURN lisp_EvalRet( cFalse )
               ELSE
                  IF cmd == "cdr"
                     nType := TYPE_LIST
                     RETURN lisp_EvalRet( cNext )
                  ELSEIF cmd == "cadr"
                     cNext := lisp_getCar( cNext, @nType )
                     IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                     RETURN lisp_EvalRet( cNext )
                  ELSEIF cmd == "caddr" .OR. cmd == "cddr"
                     cNext := lisp_getCdr( cNext, @nGetType )
                     IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
                     IF cNext == cFalse
                        nType := TYPE_ATOM
                        RETURN lisp_EvalRet( cFalse )
                     ELSEIF cmd == "caddr"
                        cNext := lisp_getCar( cNext, @nType )
                        IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF

                        // !!Temporary !!
                        //cNext := lisp_GetNextExpr( cNext, 2 )
                        //IF nLispErr > 0; RETURN Nil; ENDIF
                        //nType := Iif( Left( cNext,1 ) $ "('", TYPE_LIST, TYPE_ATOM )

                        RETURN lisp_EvalRet( cNext )
                     ELSE
                        nType := TYPE_LIST
                        RETURN lisp_EvalRet( cNext )
                     ENDIF
                  ENDIF
               ENDIF
            ELSEIF cNext == cFalse
               nType := TYPE_ATOM
               RETURN lisp_EvalRet( cFalse )
            ELSE
               nType := lisp_Error( ERR_LIST_EXPECTED,s ); RETURN Nil
            ENDIF
         ELSE
            nType := lisp_Error( ERR_BRA_EXPECTED,s ); RETURN Nil
         ENDIF

      CASE "cond"
         DO WHILE .T.
            nPos2 := 2
            cExpr := lisp_GetNextExpr( cNext, @nPos2 )
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF

            IF cExpr == cTrue .OR. ( cRes := lisp_EvalExpr( cExpr, @nGetType ) ) == cTrue
               cExpr := lisp_GetNextExpr( cNext, @nPos2 )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
               cRes := lisp_EvalExpr( cExpr, @nGetType )
               IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
               nType := nGetType
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

         IF nGetType2 == TYPE_LIST
            RETURN lisp_EvalRet( "( " + cNext + " " + Ltrim( Substr( cExpr, 2 ) ) )
         ELSE
            RETURN lisp_EvalRet( "( " + Iif( cNext == cFalse, "", cNext ) + " " + Iif( cExpr==cFalse, "", cExpr ) + ")" )
         ENDIF

      CASE "eq"
      CASE "equal"
      CASE "null"
      CASE "list"
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
         IF cmd == "list"
            nType := TYPE_LIST
            RETURN lisp_EvalRet( '(' + cNext + ' ' + cExpr + ')' )
         ELSE
            nType := TYPE_ATOM
            IF nGetType != nGetType2
               RETURN lisp_EvalRet( cFalse )
            ELSE
               RETURN lisp_EvalRet( Iif( nGetType == TYPE_LIST, ;
                  Iif( StrTran(cNext," ","") == StrTran(cExpr," ",""), cTrue, cFalse ), ;
                  Iif( cNext == cExpr, cTrue, cFalse ) ) )
            ENDIF
         ENDIF

      CASE "lambda"
         aLambda := lisp_Lambda( s, nPos, cNext )
         IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
         nType := TYPE_LAMBDA

         RETURN aLambda

      CASE "label"
         IF Left( cNext,1 ) $ "('"
            nType := lisp_Error( ERR_ATOM_EXPECTED,s ); RETURN Nil
         ELSE
            cName := cNext
         ENDIF
         //edi_Writelog( "label: " + cName )
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
         nType := TYPE_ATOM
         RETURN cTrue

      OTHERWISE
         nPos := nPos2
         IF ( nPos2 := Ascan( aLabels, {|a|a[1]==cmd} ) ) > 0
            cExpr := lisp_EvalLambda( aLabels[nPos2,2], s, nPos, @nGetType )
            nType := nGetType
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            RETURN lisp_EvalRet( cExpr )
         ELSEIF !Empty( aLambda := hb_hGetDef( aDefuns, cmd, Nil ) )
            cExpr := lisp_EvalLambda( aLambda, s, nPos, @nGetType )
            nType := nGetType
            IF nLispErr > 0; nType := lisp_Error( ,s ); RETURN Nil; ENDIF
            RETURN lisp_EvalRet( cExpr )
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

   nEvalLevel --
   edi_Writelog( Space(nEvalLevel*2) + "R>" + s )

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
      nPos := 1
      DO WHILE ( nPos := hb_At( "quote ", s, nPos ) ) > 0
         nPos1 := nPos + 6
         nPos := cedi_strSkipChars( s, nPos-1, .T. )
         IF Substr( s, nPos, 1 ) == '(' .AND. ( nPos2 := lisp_GetPairBracket( s, nPos, 0 ) ) > 0
            nPos1 := cedi_strSkipChars( s, nPos1 )
            s := Left( s, nPos-1 ) + "'" + Substr( s, nPos1, nPos2-nPos1 ) + Substr( s, nPos2+1 )
         ENDIF
      ENDDO
   ELSE
      nPos := nPos1 := hb_At( '(', s, 6 )
      nPos ++
      cName := lisp_GetNextExpr( s, @nPos )
      IF !Empty( cName )
         nPos2 := hb_At( ')', s, nPos ) + 1
         s1 := Substr( s, nPos2 )
         s2 := ""
         DO WHILE !Empty( cName )
            cNewName := '&' + Ltrim(Str(++nParamGlob)) + '&'
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
   //edi_Writelog( "EvalLambda: " + Iif( aLambda[2]==Nil,"",aLambda[2] ) )
   //edi_Writelog( "0>" + aLambda[1] )
   DO WHILE !Empty( cParam := lisp_GetNextExpr( s, @nPos ) )
      //edi_Writelog( "p"+Ltrim(Str(i-1))+">" + cParam )
      i ++
      IF i > Len( aLambda )
         lisp_Error( ERR_WRONG_PARAM_NUMBER,aLambda[1] ); RETURN Nil
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
      RETURN Iif( n == 3 .AND. Lower(s) == "nil", cFalse, s )
   ENDIF

   RETURN ""
