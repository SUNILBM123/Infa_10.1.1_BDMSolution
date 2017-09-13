#!/bin/sh

#Script argument
domainHost=${1}
domainName=${2}
domainUser=${3}
domainPassword=${4}
nodeName=${5}
nodePort=${6}

dbType=${7}
dbName=${8}
dbUser=${9}
dbPassword=${10}
dbHost=${11}
dbPort=${12}

sitekeyKeyword=${13}

joinDomain=${14}
osUserName=${15}

storageName=${16}
storageKey=${17}

domainLicenseURL=${18}

mrsdbusername=${19}
mrsdbpwd=${20}
mrsservicename=${21}
disservicename=${22}


HDIClusterName=${23}
HDIClusterLoginUsername=${24}
HDIClusterLoginPassword=${25}
HDIClusterSSHHostname=${26}
HDIClusterSSHUsername=${27}
HDIClusterSSHPassword=${28}



ambariport=${29}
HIVE_USER_NAME=${30}
HDFS_USER_NAME=${31}
BLAZE_USER=${32}
SPARK_EVENTLOG_DIR=${33}
SPARK_PARAMETER_LIST=${34}
IMPERSONATION_USER=${35}
ZOOKEEPER_HOSTS=${36}
SPARK_HDFS_STAGING_DIR=${37}
HIVE_EXECUTION_MODE=${38}
blazeworkingdir=${39}
osPwd=${40}
oneclicksolutionlog="/home/"$osUserName"/Oneclicksoluion_results.log"


echo Number of parameters $#
  if [ $# -ne 40 ]
  then
	echo converted.sh domainHost domainName domainUser domainPassword nodeName nodePort dbType dbName dbUser dbPassword dbHost dbPort sitekeyKeyword joinDomain  osUserName storageName storageKey domainLicenseURL mrsdbusername mrsdbpwd mrsservicename disservicename HDIClusterName HDIClusterLoginUsername HDIClusterLoginPassword HDIClusterSSHHostname HDIClusterSSHUsername HDIClusterSSHPassword ambariport HIVE_USER_NAME HDFS_USER_NAME BLAZE_USER SPARK_EVENTLOG_DIR SPARK_PARAMETER_LIST IMPERSONATION_USER ZOOKEEPER_HOSTS SPARK_HDFS_STAGING_DIR HIVE_EXECUTION_MODE blazeworkingdir
	exit -1
  fi


dbaddress=$dbHost:$dbPort
hostname=`hostname`

informaticaopt=/opt/Informatica/Archive
infainstallerloc=$informaticaopt/server
infainstallionloc=/home/Informatica/10.1.1
defaultkeylocation=$infainstallionloc/isp/config/keys
licensekeylocation=$informaticaopt/license.key



informaticaopt1=\\/opt\\/Informatica\\/Archive
infainstallionloc1=\\/home\\/Informatica\\/10.1.1
defaultkeylocation1=$infainstallionloc1\\/isp\\/config\\/keys
licensekeylocation1=$informaticaopt1\\/license.key

echo Creating symbolic link to Informatica installation
ln -s /home/Informatica /home/$osUserName

utilityhome=$informaticaopt/utilities
createDomain=1

JRE_HOME="$infainstallionloc/java/jre"
export JRE_HOME		
PATH="$JRE_HOME/bin":"$PATH"
export PATH
chmod -R 777 $JRE_HOME


updateFirewallsettings()
{
  echo Adding firewall rules for Informatica domain service ports
  iptables -A IN_public_allow -p tcp -m tcp --dport 6005:6008 -m conntrack --ctstate NEW -j ACCEPT
  iptables -A IN_public_allow -p tcp -m tcp --dport 6014:6114 -m conntrack --ctstate NEW -j ACCEPT
  iptables -A IN_public_allow -p tcp -m tcp --dport 18059:18065 -m conntrack --ctstate NEW -j ACCEPT
}

downloadlicense()
{
  cloudsupportenable=1
  if [ "$domainLicenseURL" != "nolicense" -a $joinDomain -eq 0 ]
  then
	cloudsupportenable=0
	cd $utilityhome
	echo Getting Informatica license from $domainLicenseURL
	java -jar iadutility.jar downloadHttpUrlFile -url "$(echo $domainLicenseURL | sed -e s/\ /%20/g)" -localpath $informaticaopt/license.key
  fi
}

checkforjoindomain()
{
  if [ $joinDomain -eq 1 ]
   then
	#echo "inside if" >> /home/$osUserName/output.out
    createDomain=0
    cloudsupportenable=1
	# This is buffer time for master node to start
	sleep 600
   else
	#echo "inside else" >> /home/$osUserName/output.out
	cd $utilityhome
    java -jar iadutility.jar createAzureFileShare -storageaccesskey $storageKey -storagename $storageName	
   fi
}

mountsharedir()
{
  yum -y install cifs-utils
  mountdir=/mnt/infaaeshare
  mkdir $mountdir
  mount -t cifs //$storageName.file.core.windows.net/infaaeshare $mountdir -o vers=3.0,username=$storageName,password=$storageKey,dir_mode=0777,file_mode=0777
  echo //$storageName.file.core.windows.net/infaaeshare $mountdir cifs vers=3.0,username=$storageName,password=$storageKey,dir_mode=0777,file_mode=0777 >> /etc/fstab
  
}

check_installation_successful()
{
   installationstatus=true
   sleep 60
   #check for silent error log
   cd /root
   silenterrorlog=$(ls -ltr | grep silentErrorLog* | cut -d ' ' -f 12)
   if [ $silenterrorlog ]
     then
        echo "there is some problem with installation. Please check silent error log">>"$oneclicksolutionlog"
        installationstatus=false
     else
        cd /home/Informatica/10.1.1
        logfiletogrep=$(ls -ltr | grep *Services*.log | cut -d ' ' -f 12)
        echo $logfiletogrep
        if [ $logfiletogrep ]
        then
          while read LINE
          do
            case "$LINE" in
              *"Installation Status:SUCCESS"*) echo "Installation completed successfully">>"$oneclicksolutionlog"; installationstatus=true;;
              *"Installation Status:ERROR"*) echo "Installation failed with status error">>"$oneclicksolutionlog"; installationstatus=false ;;
            esac
          done <$logfiletogrep
        fi
   fi

}




checkvalueisundefined()
{
   vartochk=$1
   isvardefined=false
   if [ $vartochk != "notdefined" ]
   then
      isvardefined=true
   fi

}


editsilentpropertyfilesforserverinstall()
{
    echo Editing Informatica silent installation file
#echo "License key location is :"$licensekeylocation
sed -i s/^LICENSE_KEY_LOC=.*/LICENSE_KEY_LOC=$licensekeylocation1/ $infainstallerloc/SilentInput.properties

#echo done edition of licnse key
sed -i s/^USER_INSTALL_DIR=.*/USER_INSTALL_DIR=$infainstallionloc1/ $infainstallerloc/SilentInput.properties

sed -i s/^CREATE_DOMAIN=.*/CREATE_DOMAIN=$createDomain/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_DOMAIN=.*/JOIN_DOMAIN=$joinDomain/ $infainstallerloc/SilentInput.properties

sed -i s/^CLOUD_SUPPORT_ENABLE=.*/CLOUD_SUPPORT_ENABLE=$cloudsupportenable/ $infainstallerloc/SilentInput.properties

sed -i s/^ENABLE_USAGE_COLLECTION=.*/ENABLE_USAGE_COLLECTION=1/ $infainstallerloc/SilentInput.properties

sed -i s/^KEY_DEST_LOCATION=.*/KEY_DEST_LOCATION=$defaultkeylocation1/ $infainstallerloc/SilentInput.properties

sed -i s/^PASS_PHRASE_PASSWD=.*/PASS_PHRASE_PASSWD=$(echo $sitekeyKeyword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^SERVES_AS_GATEWAY=.*/SERVES_AS_GATEWAY=1/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_TYPE=.*/DB_TYPE=$dbType/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_UNAME=.*/DB_UNAME=$dbUser/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_PASSWD=.*/DB_PASSWD=$(echo $dbPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_SERVICENAME=.*/DB_SERVICENAME=$dbName/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_ADDRESS=.*/DB_ADDRESS=$dbaddress/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_NAME=.*/DOMAIN_NAME=$domainName/ $infainstallerloc/SilentInput.properties

sed -i s/^NODE_NAME=.*/NODE_NAME=$nodeName/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_PORT=.*/DOMAIN_PORT=$nodePort/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_NODE_NAME=.*/JOIN_NODE_NAME=$nodeName/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_HOST_NAME=.*/JOIN_HOST_NAME=$hostname/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_DOMAIN_PORT=.*/JOIN_DOMAIN_PORT=$nodePort/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_USER=.*/DOMAIN_USER=$domainUser/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_HOST_NAME=.*/DOMAIN_HOST_NAME=$domainHost/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_PSSWD=.*/DOMAIN_PSSWD=$(echo $domainPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_CNFRM_PSSWD=.*/DOMAIN_CNFRM_PSSWD=$(echo $domainPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

if [ $joinDomain -ne 1 ]
 then
   sed -i s/^CREATE_SERVICES=.*/CREATE_SERVICES=1/ $infainstallerloc/SilentInput.properties
   sed -i s/^MRS_DB_TYPE=.*/MRS_DB_TYPE=$dbType/ $infainstallerloc/SilentInput.properties
   sed -i s/^MRS_DB_UNAME=.*/MRS_DB_UNAME=$mrsdbusername/ $infainstallerloc/SilentInput.properties
   sed -i s/^MRS_DB_PASSWD=.*/MRS_DB_PASSWD=$(echo $mrsdbpwd | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties
   sed -i s/^MRS_DB_SERVICENAME=.*/MRS_DB_SERVICENAME=$dbName/ $infainstallerloc/SilentInput.properties
   sed -i s/^MRS_DB_ADDRESS=.*/MRS_DB_ADDRESS=$dbaddress/ $infainstallerloc/SilentInput.properties
   sed -i s/^MRS_SERVICE_NAME=.*/MRS_SERVICE_NAME=$mrsservicename/ $infainstallerloc/SilentInput.properties
   sed -i s/^DIS_SERVICE_NAME=.*/DIS_SERVICE_NAME=$disservicename/ $infainstallerloc/SilentInput.properties
   sed -i s/^DIS_PROTOCOL_TYPE=.*/DIS_PROTOCOL_TYPE=http/ $infainstallerloc/SilentInput.properties
   sed -i s/^DIS_HTTP_PORT=.*/DIS_HTTP_PORT=18059/ $infainstallerloc/SilentInput.properties
fi

}

Performspeedupinstalloperation()
{
  mv $infainstallerloc/source $infainstallerloc/source_temp
  mv $infainstallerloc/unjar_esd.sh $infainstallerloc/unjar_esd.sh_temp
  head -1 $infainstallerloc/unjar_esd.sh_temp > $infainstallerloc/unjar_esd.sh
  echo exit_value_unjar_esd=0 >> $infainstallerloc/unjar_esd.sh
  chmod 777 $infainstallerloc/unjar_esd.sh
  mkdir $infainstallerloc/source
  
}


installdomain()
{
  echo Installing Informatica domain
  cd $infainstallerloc
  echo Y Y | sh silentinstall.sh
  echo -e "\nDomain installation completed" >> "$oneclicksolutionlog"
  check_installation_successful
  

  if [ $joinDomain -ne 1 ]
   then
     echo -e "\nStarting Debian Configuration. For results browse the logs created in ~/debianresults folder">> "$oneclicksolutionlog"
  fi
  #sleep 600
}

revertspeedupoperations()
{

 rm -rf $infainstallerloc/source
 mv $infainstallerloc/source_temp $infainstallerloc/source
 rm $infainstallerloc/unjar_esd.sh
 mv $infainstallerloc/unjar_esd.sh_temp $infainstallerloc/unjar_esd.sh
 if [ -f $informaticaopt/license.key ]
 then
   #echo bleh	
   rm $informaticaopt/license.key
 fi
 echo Informatica domain setup Complete.

}

createshellscript()
{
    mkdir -p /home/$osUserName/debianresults
    shelltowrite="/home/$osUserName/debianresults/test.sh"
    echo "#!/bin/sh" > $shelltowrite
    echo "workernodeip=\$1">>$shelltowrite
    echo "HDIClusterSSHUsername=\$2">>$shelltowrite
    echo "HDIClusterSSHPassword=\$3">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo mkdir ~/rpmtemp\"">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo chmod 777 ~/rpmtemp\"">>$shelltowrite
    echo "echo \"copying Binaries to\" \$workernodeip">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword scp -q -o StrictHostKeyChecking=no informatica_10.1.1U2-1.deb \$HDIClusterSSHUsername@\$workernodeip:\"~/rpmtemp/\"">>$shelltowrite
    echo "echo \"Installing Debian in\" \$workernodeip">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo dpkg --force-all -i ~/rpmtemp/informatica_10.1.1U2-1.deb\"">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo rm -rf ~/rpmtemp\"">>$shelltowrite
    echo "sshpass -p \$HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no \$HDIClusterSSHUsername@\$workernodeip \"sudo ln -f -s /bin/bash /bin/sh\"">>$shelltowrite
	echo "echo \"Debian Installation completed\"">>$shelltowrite
	chmod -R 777 $shelltowrite

}

configureDebian()
{
  echo Installing Debian sleeping for 2 min
  echo $HDIClusterName $HDIClusterLoginUsername $HDIClusterLoginPassword $HDIClusterSSHHostname $HDIClusterSSHUsername $HDIClusterSSHPassword
  sleep 120
  #Change sh to bash in server machine
  sudo ln -f -s /bin/bash /bin/sh
  cd $informaticaopt/debian/InformaticaHadoop-10.1.1U2-Deb
  
  #Ambari API calls to extract Head node and Data nodes
  #echo "Getting list of hosts from ambari"
  hostsJson=$(curl -u $HDIClusterLoginUsername:$HDIClusterLoginPassword -X GET https://$HDIClusterName.azurehdinsight.net/api/v1/clusters/$HDIClusterName/hosts)
  echo $hostsJson 

  echo "Parsing list of hosts"
  hosts=$(echo $hostsJson | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w 'host_name')
  echo $hosts
 
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
  
  
  
  
  rpm -ivh $informaticaopt/utilities/sshpass-1.05-5.el7.x86_64.rpm
  #Change sh to bash in headnode
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo ln -f -s /bin/bash /bin/sh"
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo mkdir" $blazeworkingdir
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo chmod -R 777" $blazeworkingdir
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo mkdir" $SPARK_HDFS_STAGING_DIR
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo chmod -R 777" $SPARK_HDFS_STAGING_DIR
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo mkdir" $SPARK_EVENTLOG_DIR
  sshpass -p $HDIClusterSSHPassword ssh -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip "sudo chmod -R 777" $SPARK_EVENTLOG_DIR

  createshellscript

  for workernode in $wnArr
  do
    echo "[$workernode]" 
	workernodeip=$(dig +short $workernode)
	echo "workernode $workernodeip"
	sh  $shelltowrite $workernodeip $HDIClusterSSHUsername $HDIClusterSSHPassword >/home/$osUserName/debianresults/$workernodeip.txt &
	
  done
  wait
  echo "out of wait"
  cd /home/$osUserName
  
  echo "Debian installation successful"
  echo -e "\nDebian configuration completed." >> "$oneclicksolutionlog"
}

separatorintermediatevariable=""
fileseparator_rep_func()
{
  
  funcpassedvar=$1
  echo "Inside function fileseparatorfunc, replacing the original value:"$funcpassedvar
  separatorintermediatevariable=""
  tstcon=1
  IFS='/' read -ra Words <<< "$funcpassedvar"
  for i in "${Words[@]}"
   do
     if [ $tstcon -gt 1 ]
      then
        separatorintermediatevariable=$separatorintermediatevariable"\\/"$i
     fi
  ((tstcon = $tstcon + 1))

   done

}

editsilentpropfiletoBDMutil()
{
  echo "editing the silent prop file for BDM utility"
  bdm_silpropfile=$infainstallionloc/tools/BDMUtil/SilentInput.properties
  sed -i s/^CLOUDERA_SELECTION=1/CLOUDERA_SELECTION=0/ $bdm_silpropfile
  sed -i s/^HD_INSIGHT=0/HD_INSIGHT=1/  $bdm_silpropfile
  sed -i s/^DIST_FOLDER__NAME=cloudera_cdh5u8/DIST_FOLDER__NAME=HDInsight_3.4/ $bdm_silpropfile
  sed -i s/^INSTALL_TYPE=0/INSTALL_TYPE=3/ $bdm_silpropfile
  sed -i s/^AMBARI_HOSTNAME=/AMBARI_HOSTNAME=$HDIClusterName.azurehdinsight.net/ $bdm_silpropfile
  sed -i s/^AMBARI_USER_NAME=/AMBARI_USER_NAME=$HDIClusterLoginUsername/ $bdm_silpropfile
  sed -i s/^AMBARI_USER_PASSWD=/AMBARI_USER_PASSWD=$HDIClusterLoginPassword/ $bdm_silpropfile
  sed -i s/^AMBARI_PORT=/AMBARI_PORT=$ambariport/ $bdm_silpropfile
  sed -i s/^UPDATE_DIS=0/UPDATE_DIS=1/ $bdm_silpropfile
  sed -i s/^DOMAIN_USER=/DOMAIN_USER=$domainUser/ $bdm_silpropfile
  sed -i s/^DOMAIN_PSSWD=/DOMAIN_PSSWD=$domainPassword/ $bdm_silpropfile
  sed -i s/^DIS_SERVICE_NAME=/DIS_SERVICE_NAME=$disservicename/ $bdm_silpropfile
  
  checkvalueisundefined $HIVE_USER_NAME
   if [ $isvardefined == "true" ]
    then
      sed -i s/^HIVE_USER_NAME=/HIVE_USER_NAME=$HIVE_USER_NAME/ $bdm_silpropfile
    fi
  
  sed -i s/^HDFS_USER_NAME=/HDFS_USER_NAME=$HDFS_USER_NAME/ $bdm_silpropfile
  
  checkvalueisundefined $BLAZE_USER
   if [ $isvardefined == "true" ]
    then
      sed -i s/^BLAZE_USER=/BLAZE_USER=$BLAZE_USER/ $bdm_silpropfile
    fi
  
  checkvalueisundefined $SPARK_EVENTLOG_DIR
   if [ $isvardefined == "true" ]
    then
       echo "updating SPARK_EVENTLOG_DIR"
       fileseparator_rep_func $SPARK_EVENTLOG_DIR
       sed -i s/^SPARK_EVENTLOG_DIR=/SPARK_EVENTLOG_DIR=$separatorintermediatevariable/ $bdm_silpropfile
   fi
  
  
  checkvalueisundefined $SPARK_PARAMETER_LIST
   if [ $isvardefined == "true" ]
    then
      sed -i s/^SPARK_PARAMETER_LIST=/SPARK_PARAMETER_LIST=$SPARK_PARAMETER_LIST/ $bdm_silpropfile
    fi
  
  checkvalueisundefined $IMPERSONATION_USER
   if [ $isvardefined == "true" ]
    then
      sed -i s/^IMPERSONATION_USER=/IMPERSONATION_USER=$IMPERSONATION_USER/ $bdm_silpropfile
    fi
  
  checkvalueisundefined $ZOOKEEPER_HOSTS
   if [ $isvardefined == "true" ]
    then
      sed -i s/^ZOOKEEPER_HOSTS=/ZOOKEEPER_HOSTS=$ZOOKEEPER_HOSTS/ $bdm_silpropfile
    fi
  
  sed -i s/^HIVE_EXECUTION_MODE=Remote/HIVE_EXECUTION_MODE=$HIVE_EXECUTION_MODE/ $bdm_silpropfile
  
  checkvalueisundefined $SPARK_HDFS_STAGING_DIR
   if [ $isvardefined == "true" ]
    then
        echo "updating sparkdir"
        fileseparator_rep_func $SPARK_HDFS_STAGING_DIR
        sed -i s/^SPARK_HDFS_STAGING_DIR=\\/tmp\\/sparkdir/SPARK_HDFS_STAGING_DIR=$separatorintermediatevariable/ $bdm_silpropfile
    fi
  
  checkvalueisundefined $blazeworkingdir
   if [ $isvardefined == "true" ]
    then
        echo "updating blazeworking dir"
        fileseparator_rep_func $blazeworkingdir
        sed -i s/^BLAZE_WORKING_DIR=\\/blaze\\/workdir/BLAZE_WORKING_DIR=$separatorintermediatevariable/ $bdm_silpropfile
    fi
  
}

runbdmutility()
{
  echo "running BDM UTILITY"
  cd $infainstallionloc/tools/BDMUtil
  echo Y Y | sh BDMSilentConfig.sh
  echo "BDM util configuration complete"
  echo -e "\nBDM util configuration completed\n" >> "$oneclicksolutionlog"
}

chownership()
{
  echo Changing ownership of directories
  chown -R $osUserName $infainstallionloc
  chown -R $osUserName /opt/Informatica 
  chown -R $osUserName /mnt/infaaeshare
  chown -R $osUserName /home/$osUserName
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

echo "downloading oneclicksnap.txt"
sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip ""sshpass -p" $osPwd "scp -q -o StrictHostKeyChecking=no oneclicksnap.txt "$osUserName"@"$domainHost":""/home/"$osUserName"

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
 
done


  #sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip ""sshpass -p" $osPwd "scp -q -o StrictHostKeyChecking=no " $python_basedir"/decrypt.sh" $osUserName"@"$domainHost":~""

  #sshpass -p $HDIClusterSSHPassword ssh -q -o StrictHostKeyChecking=no $HDIClusterSSHUsername@$headnode0ip ""sshpass -p" $osPwd "scp -q -o StrictHostKeyChecking=no " $python_basedir"/key_decryption_cert.prv" $osUserName"@"$domainHost":~""
  
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

   #update DIS property at domain level
   testline=""
   hadoopenvfileloc="$infainstallionloc/services/shared/hadoop/HDInsight_3.4/infaConf/hadoopEnv.properties"
   IFS=$'\n' read -d '' -r -a hadoopenvprops < "$hadoopenvfileloc"
   for unitline in "${hadoopenvprops[@]}"
    do
      #echo $unitline
      if [[ "$unitline" == "infapdo.env.entry.mapred_classpath"* ]]
         then
           testline=$unitline
      fi

    done

	testlineoriginal=$testline
	testline+=":$workernodehelperdir/*"

	fileseparator_rep_func "/"$testline
    separatorintermediatevariable=${separatorintermediatevariable:2}
    testline=$separatorintermediatevariable
	separatorintermediatevariable=""
    
	#fileseparator_rep_func "/"$testlineoriginal
    #separatorintermediatevariable=${separatorintermediatevariable:2}
    #testlineoriginal=$separatorintermediatevariable

	echo"replacing : "$testlineoriginal
	echo "with :" $testline

	sed -i s/infapdo.env.entry.mapred_classpath=.*/$testline/  $hadoopenvfileloc

    #sed -i s/^infapdo.env.entry.mapred_classpath=INFA_MAPRED_CLASSPATH=/infapdo.env.entry.mapred_classpath=INFA_MAPRED_CLASSPATH=$:/ $infainstallionloc/services/shared/hadoop/HDInsight_3.4/infaConf/hadoopEnv.properties

}

echo Inside main method
echo -e "Logging and debugging details for oneclick solution. \n 1> Informatica installation details will be logged in ~/Informatica/10.1.1/Informatica_10.1.1_Services_*.log \n 2> For installer failures look into silenterrorlog created in home directory \n 3> Extension script log will be created in the following drectory /var/log/azure/Microsoft.OSTCExtensions.CustomScriptForLinux/<extensionversion>/extension.log. This location may change as per Microsoft Standards." > "$oneclicksolutionlog"

updateFirewallsettings
if [ $joinDomain -ne 1 ]
 then
  downloadlicense
fi
checkforjoindomain
mountsharedir
editsilentpropertyfilesforserverinstall
Performspeedupinstalloperation
installdomain
revertspeedupoperations

if [ $joinDomain -ne 1 ]
 then
   configureDebian
   if [ $installationstatus == "false" ]
   then
     echo "since installation completed with some error, BDE util Configuration will be skipped. User has to manually run BDM util after fixing the errors">>"$oneclicksolutionlog"
   else
     echo "Starting BDM util">>"$oneclicksolutionlog"
     editsilentpropfiletoBDMutil
     runbdmutility
   fi
fi

chownership

if [ $joinDomain -ne 1 ]
 then
    # will be executed only for password environment,public ssh key user has to manually follow this step  
	checkvalueisundefined $osPwd
	if [ $isvardefined == "true" ]
    then
      copyhelperfilesfromcluster
	else
	  echo "Since the deployed environment is SSH public key, the decryption files decrypt.sh and key_decryption_cert.prv needs to copied manually from cluster environment">>"$oneclicksolutionlog"
    fi

	if [ $installationstatus == "true" ]
      then
	    fixforBDM7342
      else
	   echo "Since BDE util is not configured, update the mapred_classpath in hadoopEnv property file. For more details go through the update2 documentation">>"$oneclicksolutionlog"
    fi   
   
fi
