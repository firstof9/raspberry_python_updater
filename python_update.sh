#!/bin/bash

path=
version=
shortversion=

function pause(){
   read -p "$*"
}

download_python()
{
    wget https://www.python.org/ftp/python/$version/Python-$version.tgz
    status=$?

    if [ "$status" -gt 0 ]; then
        echo "Error downloading file."
        exit 1
    fi
}

install_pre()
{
    if [ -f /etc/debian_version ]; then
        echo "Installing prerequisite files..."
        apt-get install -y build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev >/dev/null
        status=$?

        if [ "$status" -gt 0 ]; then
            echo "Error installing prerequisite file(s)."
            exit 1
        fi
    else
        echo "You may need to install prerequisite files manually."
        pause 'Press [Enter] key to continue...'
    fi
}
extract_python()
{
    tar -zxf Python-$version.tgz > /dev/null
    status=$?

    if [ "$status" -gt 0 ]; then
        echo "Error extracting file(s)."
        exit 1
    fi
}
config_python()
{
    ./configure –prefix=/usr/local/opt/python-$version > ~/configure.log
    status=$?

    if [ "$status" -gt 0 ]; then
        echo "Error while configuring python. Please consult ~/configure.log"
        exit 1
    fi
}
build_python()
{
    make -j 4 > ~/python_build.log
    status=$?

    if [ "$status" -gt 0 ]; then
        echo "Error while building python. Please consult ~/python_build.log"
        exit 1
    fi
}

create_symlinks()
{
    ln -s /usr/local/opt/python-$version/bin/pydoc$shortversion /usr/bin/pydoc$shortversion
    ln -s /usr/local/opt/python-$version/bin/python$shortversion /usr/bin/python$shortversion
    ln -s /usr/local/opt/python-$version/bin/python$shortversionm /usr/bin/python$shortversionm
    ln -s /usr/local/opt/python-$version/bin/pyvenv-$shortversion /usr/bin/pyvenv-$shortversion
    ln -s /usr/local/opt/python-$version/bin/pip$shortversion /usr/bin/pip$shortversion
}

usage()
{
    echo "python_update - attempt to update python from soruce"
    echo " "
    echo "python_update [options]"
    echo " "
    echo "options:"
    echo "-h, --help                show brief help"
    echo "-p, --path <directory>    specify path to virtual environment ie: /srv/homeassistant/venv"
    echo "-v, --version <version>   specify version of python to update to ie: 3.7.3"
}

while [ "$1" != "" ]; do
	case $1 in
		-v | --version )    shift
							version=$1
							;;
	    -p | --path )       shift
							path=$1
							;;
		-h | --help )       usage
							exit
							;;
		* )				    usage
							exit 1
	esac
	shift
done

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run with sudo. Use \"sudo ${0} ${*}\"" 1>&2
    exit 1
elif [ -z "$version" ]; then
	echo "Missing version"
	exit 1
elif [ -z "$path" ]; then
	echo "Missing virtual environment path ie: /srv/homeassistant/venv"
	exit 1
fi

shortversion="$(cut -d '.' -f 1 <<< "$version")"."$(cut -d '.' -f 2 <<< "$version")"

echo "Installing required files..."
install_pre

echo "Downloading python version $version..."
cd /tmp
download_python

echo "Extracting files..."
extract_python

cd Python-$version/
echo "Starting install..."
config_python
echo "Compiling..."
build_python
echo "Installing files into system..."
sudo make install altinstall

# Stage 2
if [ -d "$path" ]; then
    echo "Starting Stage 2..."
    sudo -H -u homeassistant /bin/bash <<EOF
    echo "Activating virtual environment"
    source $path/bin/activate
    echo "Creating list of python modules"
    pip freeze > ~/requirements.txt
    echo "Deactivating virtual environment"
    deactivate
EOF
else
    echo "No previous virtual environment found in $path, skipping stage 2..."
fi



# Stage 3
echo "Creating venv..."
sudo -H -u homeassistant /bin/bash <<EOF
if [ ! -d "$path" ]; then
	mkdir $path
fi
cd $path
python$shortversion -m venv .
source bin/activate
if [ -f "~/requirements.txt"]; then
    echo "Reinstalling previous python modules..."
    pip install -r ~/requirements.txt
fi
deactivate
EOF

echo "Creating symlinks..."
create_symlinks

echo "Complete"
exit 0
