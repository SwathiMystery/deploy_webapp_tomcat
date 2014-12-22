deploy_webapp_tomcat
====================

This repository has a script called deploy.sh which enables you to 
deploy the webapp on tomcat by checking out the repo, packaging and building 
the artifact, clearing the previous webapps on tomcat and gracefully
handling tomcat start/stop.

Getting Started
---------------

- Edits to the script
This script does check out on Bitbucket repositories using its REST API.
This may be replaced by Github's REST API.
{TEAM_ACCOUNT_NAME} is the team account name on Bitbucket
{REPO_USER_NAME} is the Bitbucket account user name
{REPO_PASSWORD_NAME} is the Bitbucket account password

If you have custom settings.xml for maven build, then you may handle that in
<code>
	if [ ! -f $HOME/.m2/settings.xml ]; then
			echo "There is no settings.xml in ~/.m2/. Do you wanna set it up? Add here."
				fi
</code>

- Executing the script
sudo ./deploy.sh -r REPO_NAME [-m MODULE_NAME]
The usage is printed when you the run the script and it guides you in the execution.
