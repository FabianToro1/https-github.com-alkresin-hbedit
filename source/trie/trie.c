/*
 * An implementation of the trie (prefix tree).
 *
 * Copyright 2020 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "trie.h"

#include "hbapifs.h"
static void _writelog( const char * sFile, int n, const char * s, ... )
{

   if( !sFile )
      return;

   if( n )
   {
      HB_FHANDLE handle;
      if( hb_fsFile( sFile ) )
         handle = hb_fsOpen( sFile, FO_WRITE );
      else
         handle = hb_fsCreate( sFile, 0 );

      hb_fsSeek( handle,0, SEEK_END );
      hb_fsWrite( handle, s, n );
      hb_fsWrite( handle, "\r\n", 2 );
      hb_fsClose( handle );
   }
   else
   {
      FILE * hFile = hb_fopen( sFile, "a" );

      va_list ap;
      if( hFile )
      {
         va_start( ap, s );
         vfprintf( hFile, s, ap );
         va_end( ap );
         fclose( hFile );
      }
   }
}

static TRIEITEM * CreateTrieItem( TRIE * trie, char * szWord )
{
   TRIEITEM * p;
   int iLen = strlen( szWord ) - 1;

   if( trie->iLastItem == TRIE_PAGE_SIZE )
   {
      trie->iLastPage ++;
      if( trie->iLastPage == trie->iPages )
      {
         trie->iPages += TRIE_PAGES_ADD;
         trie->pages = (TRIEPAGE **) realloc( (void*)trie->pages, trie->iPages * sizeof( TRIEITEM** ) );
         memset( trie->pages + trie->iPages - TRIE_PAGES_ADD, NULL, TRIE_PAGES_ADD * sizeof( TRIEITEM** ) );
      }
      trie->pages[trie->iLastPage] = (TRIEPAGE *) malloc( TRIE_PAGE_SIZE * sizeof( TRIEITEM ) );
      trie->iLastItem = 0;
   }

   p = **(trie->pages + trie->iLastPage) + trie->iLastItem;
   trie->iLastItem ++;
   p->letter = *szWord;
   p->right = NULL;
   p->next = NULL;
   memset( p->suffix, 0, sizeof( p->suffix ) );

   //_writelog( "ac.log", 0, "cr: %lu %d %c\r\n", &(p->letter), strlen(szWord), *szWord );
   if( !iLen )
      p->suffix[0] = '\n';
   else if( iLen <= SUFFIX_LEN )
      memcpy( p->suffix, szWord+1, iLen );
   else
      p->next = CreateTrieItem( trie, szWord+1 );

   return p;
}

TRIE * trie_Create( void )
{
   TRIE * trie = (TRIE*) malloc( sizeof(TRIE) );
   int iPages = TRIE_PAGES_ADD;

   trie->pages = (TRIEPAGE **) malloc( iPages * sizeof( TRIEITEM** ) );
   memset( trie->pages, NULL, iPages * sizeof( TRIEITEM** ) );
   trie->iPages = iPages;
   trie->iLastPage = 0;
   trie->iLastItem = 0;

   trie->pages[0] = (TRIEPAGE *) malloc( TRIE_PAGE_SIZE * sizeof( TRIEITEM ) );

   return trie;
}

void trie_Close( TRIE * trie )
{
   int i;

   for( i = 0; i < trie->iPages; i++ )
      if( trie->pages[i] )
         free( trie->pages[i] );
   free( trie->pages );
   free( trie );
}

static void Add2Buff( char **pBuff, int *piBuffLen, int *piPos, char *szWord )
{
   int iLen = strlen( szWord );
   if( *piPos + iLen + 1 > *piBuffLen )
   {
      (*piBuffLen) += LIST_BUFF_LEN;
      *pBuff = (char*) realloc( *pBuff, *piBuffLen );
   }
   memcpy( *pBuff+*piPos, szWord, iLen );
   //_writelog( "ac.log", 0, "2buf: %d %d %s\r\n", *piPos, iLen, szWord );
   (*piPos) += iLen;
   (*pBuff)[*piPos] = '\n';
   //_writelog( "ac.log", 0, "2buf> %s\r\n", *pBuff );
   (*piPos) ++;
}

static int ListItems( TRIEITEM * p, char **cBuff, int *piBuffLen, int *piPos, char *szWord )
{
   int i = 0, iLen = strlen( szWord );
   char szBuff[MAX_WORD_LEN];

   while( 1 )
   {
      if( p->suffix[0] )
      {
         i ++;
         memcpy( szBuff, szWord, iLen );
         szBuff[iLen] = p->letter;
         szBuff[iLen+1] = szBuff[iLen+1+SUFFIX_LEN] = '\0';
         if( p->suffix[0] != '\n' )
            memcpy( szBuff+iLen+1, p->suffix, SUFFIX_LEN );
         //_writelog( "ac.log", 0, "li1> %s\r\n", szWord );
         //_writelog( "ac.log", 0, "li1> %s\r\n", szBuff );
         Add2Buff( cBuff, piBuffLen, piPos, szBuff );
      }
      /*else
      {
         szBuff[0] = p->letter;
         szBuff[1] = '\0';
         Add2Buff( cBuff, piBuffLen, piPos, szBuff );
      } */
      if( p->next )
      {
         memcpy( szBuff, szWord, iLen );
         szBuff[iLen] = p->letter;
         szBuff[iLen+1] = '\0';
         //_writelog( "ac.log", 0, "li2> %s\r\n", szBuff );
         i += ListItems( p->next, cBuff, piBuffLen, piPos, szBuff );
      }
      if( p->right )
         p = p->right;
      else
         break;
   }
   return i;

}

static int CountItems( TRIEITEM * p )
{
   int i = 0;

   while( 1 )
   {
      if( p->suffix[0] )
         i ++;
      if( p->next )
         i += CountItems( p->next );
      if( p->right )
         p = p->right;
      else
         break;
   }
   return i;
}

void trie_Trace( TRIE * trie, char * szWord )
{
   int iLen = strlen( szWord ), i, n = 0;
   TRIEITEM * p = **(trie->pages);
   char c;
   char s[512];

   memset( s, 0, 512 );
   for( i=0; i<iLen; i++ )
   {
      c = szWord[i];
      while( 1 )
      {
         if( c == p->letter )
         {
            if( i > 0 )
               _writelog( "trace.log", 0, "%s|\r\n", s );
            if( p->suffix[0] && p->suffix[0] != '\n' )
               _writelog( "trace.log", 0, "%s%c %c%c%c%c\r\n", s, c, p->suffix[0], p->suffix[1], p->suffix[2], p->suffix[3] );
            else
               _writelog( "trace.log", 0, "%s%c\r\n", s, c );
            break;
         }
         else if( !p->right )
         {
            return;
         }
         else
         {
            n += 4;
            if( n > 0 )
               memset( s, 32, n );
            p = p->right;
         }
      }
      if( p->next )
         p = p->next;
      else
      {
         i ++;
         break;
      }
   }
}

static int FindItem( TRIE * trie, char * szWord, TRIEITEM ** pp )
{
   int iLen = strlen( szWord ), i;
   TRIEITEM * p = **(trie->pages);
   char c;

   for( i=0; i<iLen; i++ )
   {
      c = szWord[i];
      while( 1 )
      {
         if( c == p->letter )
         {
            break;
         }
         else if( !p->right )
         {
            *pp = NULL;
            return -1;
         }
         else
            p = p->right;
      }
      if( p->next )
         p = p->next;
      else
      {
         i ++;
         break;
      }
   }
   *pp = p;
   return i;
}

static int AddItem( TRIE * trie, char * szWord )
{
   int iLen = strlen( szWord ), i;
   TRIEITEM * p = **(trie->pages);
   char c, cTemp[SUFFIX_LEN+1];

   //_writelog( "trace.log", 0, ">>%s\r\n", szWord );
   for( i=0; i<iLen; i++ )
   {
      c = szWord[i];
      while( 1 )
      {
         if( c == p->letter )
         {
            break;
         }
         else if( !p->right )
         {
            p->right = CreateTrieItem( trie, szWord + i );
            return -1;
         }
         else
            p = p->right;
      }
      if( p->next )
         p = p->next;
      else
      {
         if( p->suffix[0] && p->suffix[0] != '\n' )
         {
            i ++;
            memcpy( cTemp, p->suffix, SUFFIX_LEN );
            cTemp[SUFFIX_LEN] = '\0';
            p->next = CreateTrieItem( trie, cTemp );
            memset( p->suffix, 0, sizeof( p->suffix ) );
            AddItem( trie, szWord );
         }
         else
            p->next = CreateTrieItem( trie, szWord + i );
         return i;
      }
   }
   return i;
}

void trie_Add( TRIE * trie, char * szWord )
{
   if( !trie->iLastPage && !trie->iLastItem )
      CreateTrieItem( trie, szWord );
   else
      AddItem( trie, szWord );
}

int trie_Count( TRIE * trie, char * szWord )
{
   int i, iCou = 0;
   TRIEITEM * p;

   i = FindItem( trie, szWord, &p );
   if( i < 0 )
      return 0;

   if( p->suffix[0] )
      iCou ++;
   if( p->next )
      iCou += CountItems( p->next );

   return iCou;
}

char * trie_List( TRIE * trie, char * szWord, int * iCount )
{

   int iLen = strlen( szWord ), i, iCou = 0, iBuffLen = LIST_BUFF_LEN, iPos = 0;
   TRIEITEM * p;
   char * cBuff;
   char szBuff[MAX_WORD_LEN];

   *iCount = 0;
   i = FindItem( trie, szWord, &p );
   if( i < 0 )
      return NULL;

   cBuff = (char*) malloc( iBuffLen );

   memcpy( szBuff, szWord, iLen );
   szBuff[iLen] = p->letter;
   iLen ++;
   szBuff[iLen] = szBuff[iLen+SUFFIX_LEN] = '\0';

   if( p->suffix[0] )
   {
      iCou ++;
      if( p->suffix[0] != '\n' )
         memcpy( szBuff+iLen, p->suffix, SUFFIX_LEN );
      Add2Buff( &cBuff, &iBuffLen, &iPos, szBuff );
   }
   if( p->next )
      iCou += ListItems( p->next, &cBuff, &iBuffLen, &iPos, szBuff );

   cBuff[iPos-1] = '\0';
   *iCount = iCou;
   if( !iCou )
   {
      free( cBuff );
      cBuff = NULL;
   }
   return cBuff;
}

int trie_Exist( TRIE * trie, char * szWord )
{

   int iLen = strlen( szWord ), i, iSuffLen;
   TRIEITEM * p;

   i = FindItem( trie, szWord, &p );
   //_writelog( "ac.log", 0, "ex: %d %d \r\n", i, iLen );
   if( i < 0 )
      return 0;
   else if( i == iLen )
      return 1;
   else if( p->suffix[0] )
   {
      iSuffLen = (p->suffix[SUFFIX_LEN-1])? SUFFIX_LEN : strlen(p->suffix);
      if( iSuffLen <= ( iLen = strlen( szWord+i ) ) )
         return ( memcmp( p->suffix, szWord+i, iLen ) == 0 );
   }
   return 0;
}
