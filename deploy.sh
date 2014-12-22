#!/usr/bin/env bash

#############################
# One Click Deployment : 
# setup the webapp and deploy
# in the tomcat.
#############################

set -e

# Run me as root
if [ `whoami` != "root" ]; then
echo ""
echo "Please run me as sudo."	
echo ""
exit 1
fi

#Usage of deploy.sh
usage (){
	echo 'Usage : sudo ./deploy -r <repo_name> [-m <module_name>]'
		exit
}


# If repo_name is not given, print usage
if [[  "$#" -eq 2  ]] || [[  "$#" -eq 4 ]]
then
# Validation on repo_name
if [[ -z "$2" ]]
then
echo "Invalid argument. Please check the usage."
usage
else
echo "Repo name : $2"
fi
if [ "$#" -eq 4 ]
then
if [[ -z "$4" ]]
then
echo "Invalid argument. Please check the usage."
usage
else
echo "Module name : $4"
fi
fi
else
usage
fi



# Read args
while [ "$1" != "" ]; do
case $1 in
-r)            shift
REPO=$1
;;
-m )           shift
MODULE=$1
;;
* )           usage
exit 1
esac
shift
done


# git configuration
REPO=`echo $REPO | awk '{print tolower($0)}'`
REPO_USER={REPO_USER_NAME}
REPO_PASSWORD={REPO_PASSWORD_NAME}

TMP_REPOS_FILE="/tmp/repos.json"
#Validate repo name
curl -s  https://api.bitbucket.org/1.0/users/{TEAM_ACCOUNT_NAME}/ -u $REPO_USER:$REPO_PASSWORD > $TMP_REPOS_FILE

# List of valid git repos
function git_repos {
	PYTHON_ARG="$1" python - <<END
import json
import sys
import os
from pprint import pprint

file = os.environ['PYTHON_ARG']
jdata = open(file,"r") 
data = json.load(jdata)

arrayList = []
for doc in data['repositories']:
	arrayList.append(doc["name"].lower())

print " ".join((arrayList))
jdata.close()

END
}


# Utility Functions
die (){
	echo -e ""	
		echo $@
		exit 128
}

REPO_URL="https://"$REPO_USER":"$REPO_PASSWORD"@bitbucket.org/{TEAM_ACCOUNT_NAME}/"$REPO".git"
TEMP="$HOME/checkout"

tomcat_pid (){
	echo `ps aux | grep tomcat7 | grep -v grep | awk '{ print $2 }'`
}

tomcat_status() {
	pid=$(tomcat_pid)
		if [ -n "$pid" ]
			then
				echo "Tomcat is running with pid: $pid"
		else
			echo "Tomcat is not running"
				status() {
					pid=$(tomcat_pid)
						if [ -n "$pid" ]
							then
								echo "Tomcat is running with pid: $pid"
						else
							echo "Tomcat is not running"
								fi
				} fi
}

tomcat_start (){
	pid=$(tomcat_pid)
		if [ -n "$pid" ]
			then
				echo "Tomcat is already running (pid: $pid)"
		else
			echo "Starting Tomcat..."
				sudo service tomcat7 start
				fi

				return 0
}

# Wait to shutdown the tomcat	
SHUTDOWN_WAIT=20	

tomcat_stop() {
	pid=$(tomcat_pid)
		if [ -n "$pid" ]
			then

				echo "Stoping Tomcat"
				sudo service tomcat7 stop

				echo -n "Waiting for processes to exit ["
				let kwait=$SHUTDOWN_WAIT
				count=0;
	until [ `ps -p $pid | grep -c $pid` = '0' ] || [ $count -gt $kwait ]
		do
			echo -n ".";
		sleep 1
			let count=$count+1;
		done
			echo "Done]"

			if [ $count -gt $kwait ]
				then
					echo "Killing processes ($pid) which didn't stop after $SHUTDOWN_WAIT seconds"
					kill -9 $pid
					fi
			else
				echo "Tomcat is not running"
					fi

					return 0
}


handle_war (){
# remove the previous $REPO.war and $REPO dir if exists
# catalina base of tomcat       
	CATALINA_BASE="/var/lib/tomcat7/"

		if [[ -z "$MODULE" ]]
			then
				if [ -d "$CATALINA_BASE/webapps/$REPO*" ];
	then
		echo "$REPO exists. Replacing with new war..."

		sudo rm -rf "$CATALINA_BASE/webapps/$REPO* --verbose"
		echo "Cleanup of tomcat - work..."
		sudo rm -rf "$CATALINA_BASE/work/*"
		echo "Copying war..."
		sudo mv "$TEMP/$REPO/target/*.war" "$CATALINA_BASE/webapps/" || die "Looks like its not a webapp. Please specify the webapp module name."

				else
					echo "$REPO deploying for the first time..."
						sudo mv "$TEMP/$REPO/target/*.war" "$CATALINA_BASE/webapps/" || die "Looks like its not a webapp. Please specify the webapp module name."
						fi

		else
			if [ -d "$CATALINA_BASE/webapps/$MODULE*" ];
	then
		echo "$MODULE exists. Replacing with new war..."
		sudo rm -rf "$CATALINA_BASE/webapps/$MODULE"
		BUILD_WAR=`find $TEMP/$REPO/ -name "*.war" | grep -i $MODULE-[0-9].[0-9].[0-9]` || die "Module defined is not found. Is this a webapp?"
		sudo mv "$BUILD_WAR"  "$CATALINA_BASE/webapps/" || die "Looks like its not a webapp. Please specify the right webapp module name."

			else
				echo "$MODULE deploying for the first time..."
					BUILD_WAR=`find $TEMP/$REPO/ -name "*.war" | grep -i $MODULE-[0-9].[0-9].[0-9]` || die "Module defined is not found. Is this a webapp?"
					sudo mv "$BUILD_WAR"  "$CATALINA_BASE/webapps/" || die "Looks like its not a webapp. Please specify the right webapp module name."
					fi
					fi
}	

deploy_tomcat (){
# get the current status of tomcat and do the rest gracefully
	tomcat_stop || die "Failed stopping tomcat."
		handle_war || die "Tomcat is stopped. Error while deploying the war."
		tomcat_start || die "Failed starting tomcat."
		echo "DONE."
}

build (){
# maven package - check if module is passed in multi-module project
	BUILD_PATH="$TEMP/$REPO"	
		CUR_DIR=`pwd`
		MULTI_MODULES=`find $TEMP/$REPO/ -name "pom.xml"`

		if [[ -z "$MODULE" ]]
			then
				echo "No module defined. Building the parent pom..."
				mvn package -DskipTests=true -f "$BUILD_PATH/pom.xml" -s "$HOME/.m2/settings.xml" || die "Unable to build. Does pom.xml exist in $REPO level? Looks like pom.xml is available in : $MULTI_MODULES Please provide a module name."
				BUILD_STATUS=$?
				if [ $BUILD_STATUS -eq 0 ];
	then
		deploy_tomcat
		fi
		cd $CUR_DIR
				else
					echo "Building the module : $MODULE"
						BUILD_PATH=`find $TEMP/$REPO/ -name "pom.xml" | grep -i $MODULE/pom.xml` || die "Module defined is not found in $MULTI_MODULES"
#			BUILD_PATH="$BUILD_PATH/$MODULE"
						mvn package -DskipTests=true -f "$BUILD_PATH" -s "$HOME/.m2/settings.xml" || die "Unable to build. Is pom.xml all right  in $BUILD_PATH?"
						BUILD_STATUS=$?
						if [ $BUILD_STATUS -eq 0 ];
	then
		deploy_tomcat
		fi	 
		cd $CUR_DIR
		fi
}

checkout (){
	echo "--------------------------------"
		echo "Checking out $REPO..."
		echo "--------------------------------"

		mkdir -p $TEMP || die "Failed to make directory"

		if [ -d $TEMP ]; then
			if [ -d "$TEMP/$REPO" ]; then
				cd "$TEMP/$REPO" && git pull 
					build 
					return
					fi

					echo -e "Checking out $REPO to $TEMP ..."
					git clone $REPO_URL "$TEMP/$REPO" || cleanup 
					build
					fi
}

cleanup (){
	rm -rf $TEMP/$REPO
		echo "Checkout $TEMP/$REPO, location has been removed. Please re-run the script."
		return
}

check_dependencies (){
	CUR_DIR=`pwd`
		echo "--------------------------------"
		echo "Checking script dependencies ..."
		echo "--------------------------------"
		echo "Running update..."
		sudo apt-get update

#Check Java installation
		set +e
		java -version &>/dev/null
		JAVA_INSTALLED=$?
		if [ $JAVA_INSTALLED -eq 0 ]; 
	then
		echo "java is installed"     
		else
			echo "Installing Java..."
				sudo apt-get  --force-yes -y install python-software-properties && sudo add-apt-repository ppa:webupd8team/java && sudo apt-get update && sudo apt-get --force-yes -y install oracle-java7-installer && export JAVA_HOME=/usr/lib/jvm/java-7-oracle && sudo echo "JAVA_HOME=$JAVA_HOME" >> /etc/environment && source /etc/environment || die "Failed to install java. Please install manually"
				echo "Java is set to $JAVA_HOME"
				fi
				set -e

#Check git installation
				set +e
				git --version 2>&1 >/dev/null
				GIT_INSTALLED=$?
				if [ $GIT_INSTALLED -eq 0 ]; 
	then 
		echo "git is installed"
				else
					echo "Installing git..."
						sudo apt-get  --force-yes -y install git-core git-doc gitweb git-gui gitk git-email || die "Failed to install git. Please install manually."
						fi
						set -e

#Check maven installation
						set +e
						USERNAME=$USER
						mvn --version 2>&1 >/dev/null
						MVN_INSTALLED=$?
						if [ $MVN_INSTALLED -eq 0 ];
	then
		echo "mvn is installed"
#if settings.xml doesn't exist?
		if [ ! -f $HOME/.m2/settings.xml ]; then
			echo "There is no settings.xml in ~/.m2/. Do you wanna set it up? Add here."
				fi
		else
			echo "Installing Maven..."
				wget http://www.eng.lsu.edu/mirrors/apache/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz --no-check-certificate -P /tmp/ -nv
				cd /tmp && tar -xzvf apache-maven-3.0.5-bin.tar.gz && sudo rm -rf apache-maven-3.0.5-bin.tar.gz && sudo cp -R apache-maven-3.0.5 /usr/local && sudo ln -s /usr/local/apache-maven-3.0.5/bin/mvn /usr/bin/mvn&& sudo rm -rf apache-maven-3.0.5 && mkdir -p $HOME/.m2 && sudo chown -R $USERNAME:$USERNAME $HOME/.m2/ && cd $CUR_DIR|| die "Failed to install maven. Please install manually."
				fi
				set -e

#Check tomcat installation or status
				set +e
				sudo service tomcat7 status 2>&1 >/dev/null 
				TOMCAT_INSTALLED=$?
				if [ $TOMCAT_INSTALLED -eq 0 ];
	then
		echo "tomcat7 is installed"
				else
					echo "Installing Tomcat7..."
						sudo apt-get --force-yes -y install tomcat7 tomcat7-docs tomcat7-admin tomcat7-examples || die "Failed to install tomcat7. Please install manually."
						fi

						set -e
						cd $CUR_DIR
						checkout || cleanup || die "Checkout failed. Cleaning finished."


}


REPOS_LIST=$(git_repos $TMP_REPOS_FILE)
	declare -a list=$( echo $REPOS_LIST | tr " " "\n" )
	if [[ "${list[*]}" =~ "$REPO" ]]; then
	check_dependencies
	else
	echo "$REPO : Invalid repository."
	echo "Please check for available repos below : "
	echo "[$REPOS_LIST]"
	fi



