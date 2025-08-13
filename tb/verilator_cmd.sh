cd /home/va6053un/git/cvfpu
verilator --binary --timing --clk clk --timescale-override 1ns/1ps --relative-includes --trace\
  -Wno-UNUSEDSIGNAL \
  -Wno-UNUSEDPARAM \
  -Wno-PINCONNECTEMPTY \
  -Wno-ASCRANGE \
  -Wno-WIDTHEXPAND \
  -Wno-IMPORTSTAR \
  -Wno-VARHIDDEN \
  -Wno-UNDRIVEN \
  -Wno-WIDTHTRUNC \
  -Wno-GENUNNAMED \
  -Wno-SELRANGE \
  -Wno-LITENDIAN \
  -Wno-WIDTH \
  -Wno-UNPACKED \
  -Wno-CASEINCOMPLETE \
  -Wno-UNOPTFLAT \
  -Wno-fatal          \
  -Wno-PINCONNECTEMPTY\
  -Wno-ASSIGNDLY      \
  -Wno-DECLFILENAME   \
  -Wno-UNUSED         \
  -Wno-UNOPTFLAT      \
  -Wno-BLKANDNBLK     \
  -Wno-UNSIGNED \
  -Wno-style\
  -fno-dfg-peephole \
  +incdir+src/common_cells/include \
  src/fpu_div_sqrt_mvp/hdl/defs_div_sqrt_mvp.sv \
  src/fpu_div_sqrt_mvp/hdl/div_sqrt_top_mvp.sv \
  src/common_cells/src/cf_math_pkg.sv \
  src/common_cells/src/lzc.sv \
  src/common_cells/src/rr_arb_tree.sv \
  src/fpnew_pkg.sv \
  src/fpnew_classifier.sv \
  src/fpnew_rounding.sv \
  src/fpnew_fma.sv \
  src/fpnew_fma_multi.sv \
  src/fpnew_cast_multi.sv \
  src/fpnew_opgroup_fmt_slice.sv \
  src/fpnew_opgroup_multifmt_slice.sv \
  src/fpnew_opgroup_block.sv \
  src/fpnew_top.sv \
  tb/fpnew_tb.sv \
  -y src \
  -y src/common_cells/include \
  -y src/common_cells/src \
  -y src/common_cells/src/deprecated \
  -y src/fpu_div_sqrt_mvp/hdl \
  -y tb \
  --top-module fpnew_tb
./obj_dir/Vfpnew_tb