# hbedit
A fullscreen console multiplatform text editor.

### Project files

  + bld_edit.bat        - command file to build Hbedit for Windows (Borland C compiler).
  + bld_edit.sh         - shell script to build Hbedit for Linux.
  + bld_edit_hwg.sh     - shell script to build Hbedit for Linux with GTHWG driver
  + bld_edit_full.bat   - command file to build full Hbedit for Windows (Borland C compiler),
                        its only difference is that the full version requests most of Harbour
                        functions to provide a possibility to use them in plugins.
  + bld_plugins.bat     - command file to build plugins.
  + bld_plugins.sh      - shell script to build plugins.
  + hbedit.hbp          - project file to build hbedit with hbmk2.
  + hbedit_full.hbp     - project file to build full hbedit with hbmk2.
  + hbedit.help         - Hbedit help file (Russian).
  + hbedit_en.help      - Hbedit help file (English).
  + hbedit.ini          - Hbedit ini file.

  + source/
    + hbfuncs.ch
    + hbfuncsfull.ch    - header files.

    + cfuncs.c
    + fcmd.prg
    + fedit.prg
    + ffiles.prg
    + fkeymaps.prg
    + fgetsys.prg
    + falert.prg
    + fmenu.prg
    + hilight.prg       - editor source files, which implements the TEdit class.
                        To include the TEdit in your application you need to link them all.

    + errorsys.prg
    + hbedit.prg        - a wrapper for TEdit class, which implements the editor.

  + source/plugins/     - plugins source files
    + hb_funcs.txt          - Harbour functions list for plug_prg_init
    + hwg_funcs.txt         - HwGUI functions list for plug_prg_init
    + plug_android_project.prg - creating and maintaining java android projects
    + plug_1c_spis.prg      - 1C functions list
    + plug_bat_init.prg     - a start plugin for .bat files
    + plug_c_init.prg       - a start plugin for .c files
    + plug_calculator.prg   - Calculator
    + plug_chartable.prg    - Chartable
    + plug_gm_chess.prg     - A Chess game
    + plug_gm_life.prg      - A Life game
    + plug_gm_sokoban.prg   - A Sokoban game
    + plug_gm_strek.prg     - A Star Trek game
    + plug_gm_tetris.prg    - A Tetris game
    + plug_go_build.prg     - Golang build project
    + plug_go_fmt.prg       - Golang formatting
    + plug_go_init.prg      - a start plugin for .go files
    + plug_go_run.prg       - Golang run code
    + plug_go_spis.prg      - Golang functions list
    + plug_hbp_init.prg     - a start plugin for .hbp files
    + plug_java_init.prg    - a start plugin for .java files
    + plug_lisp_init.prg    - a start plugin for .lisp files
    + plug_palette.prg      - a current palette viewer
    + plug_php_init.prg     - a start plugin for .php files
    + plug_prg_compile.prg  - Harbour compiling
    + plug_prg_init.prg     - a start plugin for .prg files
    + plug_py_spis.prg      - Python functions list
    + plug_prg_run.prg      - Harbour run
    + plug_prg_run1c.prg    - Harbour for 1c
    + plug_selection.prg    - Additional operations on selected region
    + plug_sh_init.prg      - a start plugin for .sh files
    + plug_vcs.prg          - a plugin to work with Git and Fossil
    + plug_webservices.prg  - Some web services access

### Usage

  The Hbedit may be used as a class, as a library to incorporate it to your application.
  You just need to compile and link the Tedit source files ( cfuncs.c, fcmd.prg, fedit.prg,
  ffiles.prg, fmenu.prg, hilight.prg ) and put following lines:

      oEdit := TEdit():New( Memoread("my.txt"), "my.txt" )
      oEdit:Edit()

  to edit, for example, a file "my.txt".

  Also, compiled and linked with hbedit.prg, it is a standalone editor.

### Hbedit command line parameters
  
  hbedit [-f iniFileName] [-gN] [-xy=xPos,yPos] [-size=nCols,nRows] [-ro] [files...]

  - -f iniFileName      - a name of ini file to use instead of hbedit.ini
  - -gN                 - goto line N; If N is negative it is a number of lines before the end
  - -xy=xPos,yPos       - initial window position in pixels (for Windows only)
  - -size=nCols,nRows   - number of columns and rows in an editor window
  - -ro                 - open file in a readonly mode
  - -d                  - open two files side-by-side in diff mode
  - -cp=CP              - sets CP codepage as default
  - -pal=paletteName    - sets paletteName as default palette
  - -his=N              - overrides 'savehis' option
  - files...            - the list of files to edit


### hbedit.ini

 hbedit.ini includes many important options, you may edit it to tune the editor.
 See detailed description at http://www.kresin.ru/en/hbedit.html

### Download
   You may download some ready binaries from http://www.kresin.ru/en/hbedit.html
