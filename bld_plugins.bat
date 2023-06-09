@echo off
set HB_INSTALL_BIN=c:\harbour\bin

cd source\plugins
harbour plug_1c_spis.prg -n -gh -q
harbour plug_android_project.prg -n -gh -q
harbour plug_c_init.prg -n -gh -q
harbour plug_bat_init.prg -n -gh -q
harbour plug_go_init.prg -n -gh -q
harbour plug_go_spis.prg -n -gh -q
harbour plug_go_fmt.prg -n -gh -q
harbour plug_go_run.prg -n -gh -q
harbour plug_go_build.prg -n -gh -q
harbour plug_php_init.prg -n -gh -q
harbour plug_prg_compile.prg -n -gh -q
harbour plug_prg_init.prg -n -gh -q
harbour plug_prg_run.prg -n -gh -q
harbour plug_py_spis.prg -n -gh -q
harbour plug_hbp_init.prg -n -gh -q
harbour plug_java_init.prg -n -gh -q
harbour plug_lisp_init.prg -n -gh -q
harbour plug_sh_init.prg -n -gh -q
harbour plug_selection.prg -n -gh -q
harbour plug_chartable.prg -n -gh -q
harbour plug_calculator.prg -n -gh -q
harbour plug_palette.prg -n -gh -q
harbour plug_gm_tetris.prg -n -gh -q
harbour plug_gm_sokoban.prg -n -gh -q
harbour plug_gm_strek.prg -n -gh -q
harbour plug_gm_sudoku.prg -n -gh -q
harbour plug_gm_life.prg -n -gh -q
harbour plug_gm_chess.prg -n -gh -q
harbour plug_gm_ugolki.prg -n -gh -q
harbour plug_webservices.prg -n -gh -q
harbour plug_vcs.prg -n -gh -q
harbour lisp_run.prg -n -gh -q
cd ..\..\

