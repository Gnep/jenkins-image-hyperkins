#! /bin/bash -e

: ${JENKINS_HOME:="/var/jenkins_home"}
touch "${COPY_REFERENCE_FILE_LOG}" || (echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?" && exit 1)
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find /usr/share/jenkins/ref/ -type f -exec bash -c ". /usr/local/bin/jenkins-support; copy_reference_file '{}'" \;

#ensure dir ($JENKINS_HOME maybe a empty dir)
mkdir -p $JENKINS_HOME/secrets $JENKINS_HOME/init.groovy.d
mkdir -p ${JENKINS_HOME}/bin

#ensure hyper cli and config dir
if [ ! -f ${JENKINS_HOME}/bin/hyper ];then
  cp /usr/local/bin/hyper ${JENKINS_HOME}/bin/hyper
fi

#prepare run mode(unlock jenkins automatically)
if [ "${PRODUCTION}" == "true" ];then
  echo "==============================="
  echo "Run jenkins in production mode"
  echo "==============================="
  # Configure Global Security -> [check] Enable Slave → Master Access Control
  echo -n false > $JENKINS_HOME/secrets/slave-to-master-security-kill-switch
  # ensure basic-security.groovy not exist
  if [ -f /var/lib/jenkins/init.groovy.d/basic-security.groovy ];then
    echo "found '/var/lib/jenkins/init.groovy.d/basic-security.groovy', backup it"
    mv /var/lib/jenkins/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak
  fi
  if [ -f $JENKINS_HOME/init.groovy.d/basic-security.groovy ];then
    echo "found '$JENKINS_HOME/init.groovy.d/basic-security.groovy', rename it!"
    mv $JENKINS_HOME/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak
  fi
else
  echo "==============================="
  echo "run jenkins in development mode"
  echo "-------------------------------"
  # Configure Global Security -> [check] Enable Slave → Master Access Control
  echo -n true > $JENKINS_HOME/secrets/slave-to-master-security-kill-switch
  # skip setup wizard
  echo "(skip setup wizard)"
  if [ -f $JENKINS_HOME/init.groovy.d/basic-security.groovy ];then
      echo "jenkins initialize already, rename 'basic-security.groovy' and skip!"
      mv $JENKINS_HOME/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak
      rm -rf /var/lib/jenkins/init.groovy.d/basic-security.groovy >/dev/null 2>&1
  elif [ -f $JENKINS_HOME/init.groovy.d/basic-security.groovy.bak ];then
      echo "jenkins initialize already, skip!"
      rm -rf /var/lib/jenkins/init.groovy.d/basic-security.groovy >/dev/null 2>&1
  elif [ -f /var/lib/jenkins/init.groovy.d/basic-security.groovy ];then
      echo "initialize..."
      mv /var/lib/jenkins/init.groovy.d/basic-security.groovy $JENKINS_HOME/init.groovy.d/basic-security.groovy
      mv /var/lib/jenkins/jenkins.install.UpgradeWizard.state $JENKINS_HOME/jenkins.install.UpgradeWizard.state
      if [ "${ADMIN_PASSWORD}" == "" ];then
        ADMIN_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32;echo)
        echo "Generate admin password: ${ADMIN_PASSWORD}"
      fi
      sed -i "s/%ADMIN_USERNAME%/${ADMIN_USERNAME}/g" $JENKINS_HOME/init.groovy.d/basic-security.groovy
      sed -i "s/%ADMIN_PASSWORD%/${ADMIN_PASSWORD}/g" $JENKINS_HOME/init.groovy.d/basic-security.groovy
  else
    cat <<EOF

[WARN] Missing one of the following files:
---------------------------------------------------------
- /var/lib/jenkins/init.groovy.d/basic-security.groovy
- ${JENKINS_HOME}/init.groovy.d/basic-security.groovy
- ${JENKINS_HOME}/init.groovy.d/basic-security.groovy.bak
---------------------------------------------------------

EOF
  fi
  export JAVA_OPTS="-Dhudson.Main.development=true -Djenkins.install.runSetupWizard=false"
  echo "==============================="
fi

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
  eval "exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war $JENKINS_OPTS \"\$@\""
fi

# As argument is not jenkins, assume user want to run his own process, for sample a `bash` shell to explore this image
exec "$@"
