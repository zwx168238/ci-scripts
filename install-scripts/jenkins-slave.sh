sudo apt-get install git openssh-server

cd ~/Download
wget -q -c https://releases.linaro.org/15.02/components/toolchain/binaries/aarch64-linux-gnu/gcc-linaro-4.9-2015.02-3-x86_64_aarch64-linux-gnu.tar.xz
sudo mkdir /opt
sudo tar -Jxf gcc-linaro-4.9-2015.02-3-x86_64_aarch64-linux-gnu.tar.xz -C /opt/
echo "export PATH=/opt/gcc-linaro-4.9-2015.02-3-x86_64_aarch64-linux-gnu/bin:$PATH">> ~/.bashrc

#create /srv/mirrors/linux.git
sudo mkdir -p /srv/mirrors
sudo git clone https://github.com/hisilicon/linaro-kernel.git /srv/mirror/linux.git
