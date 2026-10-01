#!/bin/bash
#
# Assemble one DLX test program into the two memory images the testbench reads.
#
#   ./assembler.sh [-w <words>] <file.asm> [imem_image] [dmem_init_image]
#
# With no image paths given, both land next to the .asm under the names the
# rest of the flow expects:
#       <dir>/<name>_imem.txt        instruction ROM   (romem / simple_iram)
#       <dir>/<name>_dmem_init.txt   initial data RAM  (rwmem / simple_dram)
# plus <name>.bin and <name>.list for reference.
#
# One 32-bit word per line, 8 upper-case hex digits, <words> lines -- the
# format hread() expects.  The instruction image is padded with NOP
# (0x54000000), never 0x00000000, which this CPU decodes as illegal.
#
# -w/--words is the SAME number that has to reach:
#       TB_DLX      -gmemory_size=<words>   (sim.do passes it)
#       dlxsim.py   -w <words>
# run_tests.tcl owns that number and passes it to all three; it is not
# hardcoded here.
#
# dlxasm.pl writes the images itself (-mem / -datamem), so nothing here needs
# hexdump or od.

words=512                       # fallback only, when -w is not given

while [ $# -gt 0 ]
do
	case "$1" in
		-w|--words)
			if [ -z "$2" ]
			then
				echo "$0: -w needs a word count" >&2
				exit 1
			fi
			words="$2"
			shift 2
			;;
		-w=*|--words=*)
			words="${1#*=}"
			shift
			;;
		-h|--help)
			echo "Usage: $0 [-w <words>] <file.asm> [imem_image] [dmem_init_image]"
			exit 0
			;;
		--)
			shift
			break
			;;
		-*)
			echo "$0: unknown option $1" >&2
			exit 1
			;;
		*)
			break
			;;
	esac
done

case "$words" in
	''|*[!0-9]*)
		echo "$0: word count must be a positive integer, got '$words'" >&2
		exit 1
		;;
esac

if [ ! -r "$1" ]
then
	echo "Usage: $0 [-w <words>] <file.asm> [imem_image] [dmem_init_image]"
	exit 1
fi

asmfile="${1%.*}"               # path without the .asm extension
imem="${2:-${asmfile}_imem.txt}"
dmem="${3:-${asmfile}_dmem_init.txt}"

perl ../../sim/assembler/dlxasm.pl \
    -o "$asmfile.bin" \
    -list "$asmfile.list" \
    -mem "$imem" \
    -datamem "$dmem" \
    -memsize "$words" \
    "$1" || exit 1

rm -f "$asmfile.bin.hdr"

echo "  imem      -> $imem  ($words words)"
echo "  dmem_init -> $dmem  ($words words)"
