#!/bin/bash
## This is a compilation procedure that worked for me to setup the python-meep 
## with some utilities on a Debian-based system.

## --- Settings ---------------------------------------------------------------
MPI="openmpi"
#MPI="mpich"
#MPI="mpich2"
#MPI="serial"			## i.e. no multiprocessing used

if [ "$MPI" = "openmpi" ] || [ "$MPI" = "mpich" ] || [ "$MPI" = "mpich2" ] ; then meep_opt="--with-mpi"; fi

## --- Build dependencies -----------------------------------------------------
## (list obtained from https://launchpad.net/ubuntu/quantal/+source/meep)
sudo apt-get update
sudo apt-get install -y autotools-dev autoconf chrpath debhelper gfortran \
    g++ git guile-2.0-dev h5utils imagemagick libatlas-base-dev libfftw3-dev libgsl0-dev \
    libharminv-dev  liblapack-dev libtool pkg-config swig  zlib1g-dev

sudo apt-get -y install lib$MPI-dev libhdf5-$MPI-dev  			## OpenMPI version (TODO: try removing libhdf5-cpp-8)libhdf5-cpp-8
#sudo apt-get -y install $MPI-bin		 ## TODO remove?

## for Ubuntu 15.04: fresh libctl 3.2.2 is in repository
sudo apt-get install -y libctl-dev							
## for Ubuntu 14.04, or older:  the version of `libctl-dev' in repository is too old, needs a fresh compile:
#  wget http://ab-initio.mit.edu/libctl/libctl-3.2.1.tar.gz
#  tar xzf libctl* && cd libctl-3.2.1/
#  ./configure LIBS=-lm  &&  make  &&  sudo make install
#  cd ..

## --- MEEP (now fresh from github!) --------------------------------------------
export CFLAGS=" -fPIC"; export CXXFLAGS=" -fPIC"; export FFLAGS=" -fPIC"  ## Position Independent Code, needed on 64-bit
export CPPFLAGS="-I/usr/include/hdf5/$MPI"
export LDFLAGS="-L/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/hdf5/$MPI"

## Note: If the git version was unavailable, use the failsafe alternative below
#if [ ! -d "meep" ]; then git clone https://github.com/filipdominec/meep; fi   ## FD's branch, see github
if [ ! -d "meep" ]; then git clone https://github.com/stevengj/meep; fi
cd meep/
./autogen.sh $meep_opt --enable-maintainer-mode --enable-shared --prefix=/usr/local  # exits with 1 ?
make  &&  sudo make install
cd ..

## Failsafe alternative if git not working: download the 1.2.1 sources (somewhat obsoleted)
#if [ ! -d "meep" ]; then wget http://ab-initio.mit.edu/meep/meep-1.3.tar.gz && tar xzf meep-1.3.tar.gz && mv meep-1.3 meep; fi
#cd meep/
#./configure $meep_opt --enable-maintainer-mode --enable-shared --prefix=/usr/local  &&  make  &&  sudo make install
#cd ..

## --- PYTHON-MEEP ------------------------------------------------------------
## Install python-meep dependencies and SWIG
sudo apt-get install python-dev python-numpy python-scipy -y

## Get the latest source from green block at https://launchpad.net/python-meep/1.4
if [ ! -d "python-meep" ]; then
	wget https://launchpad.net/python-meep/1.4/1.4/+download/python-meep-1.4.2.tar
	tar xf python-meep-1.4.2.tar
fi

## If libmeep*.so was installed to /usr/local/lib, this scipt has to edit the installation scripts (aside
## from passing the "-I" and "-L" parameters to the build script).
cd python-meep/
pm_opt=`echo $meep_opt | sed 's/--with//g'`
sed -i -e 's:/usr/lib:/usr/local/lib:g' -e 's:/usr/include:/usr/local/include:g' ./setup${pm_opt}.py
sed -i -e '/custom.hpp/ a export LD_RUN_PATH=\/usr\/local\/lib' make${pm_opt}
sed -i -e 's/#global/global/g' -e 's/#DISABLE/DISABLE/g' -e 's/\t/    /g'  meep-site-init.py
sudo ./make${pm_opt} -I/usr/local/include -L/usr/local/lib
