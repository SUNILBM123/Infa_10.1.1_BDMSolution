HDIClusterName=${1}
HDIClusterLoginUsername=${2}
HDIClusterLoginPassword=${3}
HDIClusterSSHHostname=${4}
HDIClusterSSHUsername=${5}
HDIClusterSSHPassword=${6}
blazeworkingdir=${7}
SPARK_HDFS_STAGING_DIR=${8}
SPARK_EVENTLOG_DIR=${9}
osUserName=${10}
osPwd=${11}
domainHost=${12}
domainusername=${13}
domainpassword=${14}
infahome=${15}
domainname={16}

debianlocation=/opt/Informatica/Archive/debian/InformaticaHadoop-10.1.1U2-Deb

removeconnection()
{
   cd $infahome/isp/bin
   sh infacmd.sh removeConnection -dn $domainname -un $domainusername -pd $domainpassword -cn HADOOP
   sh infacmd.sh removeConnection -dn $domainname -un $domainusername -pd $domainpassword -cn HBASE
   sh infacmd.sh removeConnection -dn $domainname -un $domainusername -pd $domainpassword -cn HDFS
   sh infacmd.sh removeConnection -dn $domainname -un $domainusername -pd $domainpassword -cn HIVE  

}

rerunbdmutil()
{
   echo "running BDM UTILITY"
   cd $infahome/tools/BDMUtil
   echo Y Y | sh BDMSilentConfig.sh
   echo "BDM util configuration complete"
  
}




getclusterdetails()
{
  echo "Getting list of hosts from ambari"
  hostsJson=$(curl -u $HDIClusterLoginUsername:$HDIClusterLoginPassword -X GET https://$HDIClusterName.azurehdinsight.net/api/v1/clusters/$HDIClusterName/hosts)
  
  echo "Parsing list of hosts"
  hosts=$(echo $hostsJson | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w 'host_name')
  echo $hosts
  
  
  #additional configurations required
  echo "Extracting headnode0"
  headnode0=$(echo $hosts | grep -Eo '\bhn0-([^[:space:]]*)\b') 
  echo $headnode0
  echo "Extracting headnode0 IP addresses"
  headnode0ip=$(dig +short $headnode0) 
  echo "headnode0 IP: $headnode0ip"
  resulthost=$(sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "uname -a | cut -d ' ' -f 2")
  echo "resulthost name is:"$resulthost  

  #Add a new line to the end of hosts file
  echo "">>/etc/hosts
  echo "Adding headnode IP addresses"
  echo "$headnode0ip headnodehost $resulthost $headnode0">>/etc/hosts
 
 
  echo "Extracting workernode"
  workernodes=$(echo $hosts | grep -Eo '\bwn([^[:space:]]*)\b') 
  echo "Extracting workernodes IP addresses"
  echo "workernodes : $workernodes" 
  wnArr=$(echo $workernodes | tr "\n" "\n")
}

removeknownhostentries()
{
  sudo ssh-keygen -f /root/.ssh/known_hosts -R $headnode0ip
  sudo ssh-keygen -f /root/.ssh/known_hosts -R $headnode0
  for workernode in $wnArr
  do
    echo "[$workernode]" 
	workernodeip=$(dig +short $workernode)
	echo "workernode $workernodeip"
    sudo ssh-keygen -f /root/.ssh/known_hosts -R $workernodeip
	sudo ssh-keygen -f /root/.ssh/known_hosts -R $workernode

  done
}

removeetchost()
{
  matchstring="headnodehost"

  if [ -n "$(grep $matchstring /etc/hosts)" ]
  then
     echo "removing previous headnode entry"
     sed -i "/$matchstring/d" /etc/hosts

  else
     echo "nothing to remove"

   fi

}

createstagingdir()
{
  echo "creating staging directories"
   sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo ln -f -s /bin/bash /bin/sh"
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "hadoop fs -mkdir -p" $blazeworkingdir
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "hadoop fs -chmod 777" $blazeworkingdir
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "hadoop fs -mkdir -p" $SPARK_HDFS_STAGING_DIR
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "hadoop fs -chmod 777" $SPARK_HDFS_STAGING_DIR
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "hadoop fs -mkdir -p" $SPARK_EVENTLOG_DIR
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "hadoop fs -chmod 777" $SPARK_EVENTLOG_DIR


}


createshellscript()
{
    
    shelltowrite="test.sh"
    
    echo "#!/bin/sh" > $shelltowrite
    echo "workernodeip=\$1">>$shelltowrite
    echo "HDIClusterSSHUsername=\$2">>$shelltowrite
    echo "HDIClusterSSHPassword=\$3">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo mkdir ~/rpmtemp\"">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo chmod 777 ~/rpmtemp\"">>$shelltowrite
    echo "echo \"copying Binaries to\" \$workernodeip">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword scp -q -o StrictHostKeyChecking=no $debianlocation/informatica_10.1.1U2-1.deb \$HDIClusterSSHUsername@\$workernodeip:\"~/rpmtemp/\"">>$shelltowrite
    echo "echo \"Installing Debian in\" \$workernodeip">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo chmod -R 777 ~/rpmtemp\"">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo dpkg --force-all -i ~/rpmtemp/informatica_10.1.1U2-1.deb\"">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo rm -rf ~/rpmtemp\"">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo ln -f -s /bin/bash /bin/sh\"">>$shelltowrite
	echo "echo \"Debian Installation completed\"">>$shelltowrite
	chmod -R 777 $shelltowrite

}

installdebian()
{
  echo "Installing debian"
  for workernode in $wnArr
  do
    echo "[$workernode]" 
	workernodeip=$(dig +short $workernode)
	echo "workernode $workernodeip"
       sudo sh  $shelltowrite $workernodeip $HDIClusterSSHUsername $HDIClusterSSHPassword >$workernodeip.txt &
	
  done
  wait
  echo "out of wait"
  echo "Debian installation successful"
   
}

copyhelperfilesfromcluster()
{
      
#remove already existing authentication id of vm if any
remote_knownhostsfile="/home/"$HDIClusterSSHUsername"/.ssh/known_hosts"
sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip ""sudo ssh-keygen -f "$remote_knownhostsfile" -R " $domainHost"


echo "Installing sshpass on cluster" 
sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo apt install sshpass "
echo "searching for file in remote cluster"
sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo find / -name decrypt.sh >oneclicksnap.txt"
sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo find / -name key_decryption_cert.prv >>oneclicksnap.txt"  
sleep 5
echo "downloading oneclicksnap.txt"
echo sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip ""sshpass -p" $osPwd "scp -q -o StrictHostKeyChecking=no oneclicksnap.txt "$osUserName"@"$domainHost":""/home/"$osUserName"

sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip ""sshpass -p" $osPwd "scp -q -o StrictHostKeyChecking=no oneclicksnap.txt "$osUserName"@"$domainHost":""/home/"$osUserName"

echo "downloading done"
sleep 20

#code to iterate snap.txt and download the file and copy to it to local directory

counter=0
skipcount=2
filename="/home/"$osUserName"/oneclicksnap.txt"
echo "displaying the content of downloaded file"
cat $filename

echo "parsing and processing the file contents"

IFS=$'\n' read -d '' -r -a totalfiles < "$filename"

for line in "${totalfiles[@]}"
do
  name="$line"
  echo "downloading file:"$name
  
  sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip ""sshpass -p" $osPwd "scp -q -o StrictHostKeyChecking=no "$name $osUserName"@"$domainHost":""~""  
  
  IFS='/' read -ra NAMES <<< "$name"
  counter=${#NAMES[@]}
  ((chckcounter=$counter - $skipcount))
   #$basechkcounter=$chckcounter

  intermediatestring=""
  while [ $chckcounter -gt 0 ]
  do
    #echo ${NAMES[$chckcounter]}
    intermediatestring=${NAMES[$chckcounter]}/$intermediatestring
    ((chckcounter=$chckcounter - 1))
  done

  intermediatestring=/$intermediatestring
  #echo $intermediatestring
  #echo ${NAMES[(counter-1)]}
  echo "creating directory:"$intermediatestring
  mkdir -p $intermediatestring
  sleep 5
  echo "moving file:"${NAMES[(counter-1)]}
  mv /home/$osUserName/${NAMES[(counter-1)]} $intermediatestring
  chmod -R 777 $intermediatestring 
done
  
  echo "Removing sshpass installation on cluster"
  sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo apt-get --purge remove sshpass --assume-yes"


}

fixforBDM7342()
{
   workernodehelperdir="/home/helper"
   for workernode in $wnArr
   do
	#statements
	workernodeip=$(dig +short $workernode)
	echo "creating directory in :"$workernode

	sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip ""sudo mkdir "$workernodehelperdir"

	sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip ""sudo ln -sf /etc/hadoop/conf/hdfs-site.xml "$workernodehelperdir"
	sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip ""sudo ln -sf /etc/hadoop/conf/core-site.xml "$workernodehelperdir"
	sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$workernodeip ""sudo ln -sf /etc/hadoop/conf/mapred-site.xml "$workernodehelperdir"

   done
   
  
      
}


echo "Inside Main"
removeetchost
getclusterdetails
removeknownhostentries
removeconnection
rerunbdmutil
createstagingdir
createshellscript
installdebian
copyhelperfilesfromcluster
fixforBDM7342
