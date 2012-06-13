#!/bin/bash

nargs=3  # Arguments of the script: 
         #  time step 
         #  number parts 
         #  number of syncio files wanted

# Function die called when there is a problem 
function die() {
        echo -e "${1}"
        exit 1
}


# check that user entered proper number of args
if [ "${#}" -lt "$nargs" ] || [ "$1" == "-h" ]; then
        die "\n Check usage: \n  $0\n\n \$1: <time step>\n \$2: <number of parts>\n \$3: <number of SyncIO files>\n\n"
fi


N_steps=$1
N_parts=$2
N_files=$3

echo "Time step: $N_steps"
echo "Number of parts: $N_parts" 
echo "Number of SyncIO files: $N_files"
echo ""

dir=$N_parts-procs_case

#Do a couple of sanity check on the input parameters of the script
if [ ! -d $dir ]; then
	die "$N_parts-procs_case does not exist\n Aborting"		
fi

if [ ! -e $dir/restart.$N_steps.1 ]; then
        die "Time step $N_steps does not exist in $N_parts-procs_case\n Aborting"
fi

resmodulo=$(($N_parts % $N_files))
if [ "$resmodulo" -ne "0" ]; then
        die "The number of SyncIO files requested $N_files is not a multiple of the number of parts $N_parts\n Aborting"
fi




#First, count the interior and boundary topology blocks
grep -a ' : < ' $dir/geombc.dat.* | grep 'connectivity interior' | awk -F : '{print $1,$2}' | awk '{$1=""; print $0}' | sort | uniq -c  > list_tpblocks.dat
interior_tpblocks=`cat list_tpblocks.dat | wc -l`
echo "There are $interior_tpblocks different interior tp blocks in all the geombc files:"
cat list_tpblocks.dat
rm list_tpblocks.dat
echo ""

grep -a ' : < ' $dir/geombc.dat.* | grep 'connectivity boundary' | awk -F : '{print $1,$2}' | awk '{$1=""; print $0}' | sort | uniq -c  > list_tpblocks.dat
boundary_tpblocks=`cat list_tpblocks.dat | wc -l`
echo "There are $boundary_tpblocks different boundary tp blocks in all the geombc files:"
cat list_tpblocks.dat
rm list_tpblocks.dat
echo ""

#Now, create the IO.O2N.input file required by the converter
file=IO.O2N.input
if [ -e $file ]; then
	rm $file
fi

N_geombc_fields_double=$((2+$boundary_tpblocks))
N_geombc_fields_integer=$((14+$interior_tpblocks+2*$boundary_tpblocks))
N_restart_fields_double=1
N_restart_fields_integer=3


echo "N-geombc-fields-double:   $N_geombc_fields_double;" >> $file
echo "N-geombc-fields-integer:  $N_geombc_fields_integer;" >> $file
echo "N-restart-fields-double:  $N_restart_fields_double;" >> $file
echo "N-restart-fields-integer: $N_restart_fields_integer;" >> $file
echo "N-steps: $N_steps;" >> $file
echo "N-parts: $N_parts;" >> $file
echo "N-files: $N_files;" >> $file
echo "geombc, co-ordinates,                                 double,   block,     2;" >> $file
echo "geombc, boundary condition array,                     double,   block,     1;" >> $file
for ((i=1; i<=$boundary_tpblocks; i++))
do
	echo "geombc, nbc values?,                                  double,   block,     8;" >> $file
done
echo "geombc, number of nodes,                              integer,  header,    1;" >> $file
echo "geombc, number of modes,                              integer,  header,    1;" >> $file
echo "geombc, number of interior elements,                  integer,  header,    1;" >> $file
echo "geombc, number of boundary elements,                  integer,  header,    1;" >> $file
echo "geombc, maximum number of element nodes,              integer,  header,    1;" >> $file
echo "geombc, number of interior tpblocks,                  integer,  header,    1;" >> $file
echo "geombc, number of boundary tpblocks,                  integer,  header,    1;" >> $file
echo "geombc, number of nodes with Dirichlet BCs,           integer,  header,    1;" >> $file
for ((i=1; i<=$interior_tpblocks; i++))
do
	echo "geombc, connectivity interior?,                       integer,  block,     7;" >> $file
done
echo "geombc, number of shape functions,                    integer,  header,    1;" >> $file
echo "geombc, size of ilwork array,                         integer,  header,    1;" >> $file
echo "geombc, ilwork,                                       integer,  block,     1;" >> $file
echo "geombc, bc mapping array,                             integer,  block,     1;" >> $file
echo "geombc, bc codes array,                               integer,  block,     1;" >> $file
echo "geombc, periodic masters array,                       integer,  block,     1;" >> $file
for ((i=1; i<=$boundary_tpblocks; i++))
do
	echo "geombc, connectivity boundary?,                       integer,  block,     8;" >> $file
#	echo "geombc, nbc codes?,                                   integer,  block,     8;" >> $file
done
for ((i=1; i<=$boundary_tpblocks; i++))
do
#	echo "geombc, connectivity boundary?,                       integer,  block,     8;" >> $file
	echo "geombc, nbc codes?,                                   integer,  block,     8;" >> $file
done
echo "restart, solution,                                    double,   block,     3;" >> $file
echo "restart, byteorder magic number,                      integer,  block,     1;" >> $file
echo "restart, number of modes,                             integer,  header,    1;" >> $file
echo "restart, number of variables,                         integer,  header,    1;" >> $file

echo "$file generated for the converter"
