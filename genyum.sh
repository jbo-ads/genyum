# genyum.sh - Create a self installing YUM repository for offline use

# Create a temporary working directory
TMPDIR=$(mktemp -d /tmp/genyum.XXXXXXX)
tmpname=$(basename $TMPDIR)
mkdir $TMPDIR/repo
cd $TMPDIR/repo

# Populate directory with requested RPMs and their dependencies
repotrack $*

# Make a YUM repository from directory containing RPMs
createrepo .
cd ..

# Add ancillary files to archive
cat << REPOCONF_EOF > $tmpname.repo
[$tmpname]
name=Custom Packages and Dependencies ($tmpname)
baseurl=file://$TMPDIR/repo/
gpgcheck=0
enabled=0
REPOCONF_EOF

# Create autoextracting archive
cd ..
tar czf $tmpname.tgz $tmpname/

cat << INSTALLDEPS_EOF > installdeps.sh
if cat /var/log/cron >& /dev/null
then
  # Command line arguments specify which packages shall be installed
  # This defaults to all packages contained in the archive
  deps="$*"
  test \$# -gt 0 && deps=\$*

  # Find where actual archive starts and extract it
  plstart=\$(awk '/^__PAYLOAD_BELOW__/{print NR+1;exit 0;}' \$0)
  tail -n+\$plstart \$0 | tar xz -C $(dirname $TMPDIR)
  
  # Declare the newly installed YUM repository and use it
  cp $TMPDIR/$tmpname.repo /etc/yum.repos.d/$tmpname.repo
  yum install -y --disablerepo=* --enablerepo=$tmpname \$deps
  exit 0
else
  # Installer needs root privileges
  echo sudo required
  exit 1
fi
__PAYLOAD_BELOW__
INSTALLDEPS_EOF

cat $tmpname.tgz >> installdeps.sh
chmod +x installdeps.sh

# Cleanup
rm -rf $tmpname.tgz $tmpname

# Report location of autoextracting archive
printf "\n\nAutoextracting archive is %s\n" $(pwd)/installdeps.sh

################################################################################
