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

cat << INSTALLYUM_EOF > installyum.sh
if cat /var/log/cron >& /dev/null
then
  plstart=\$(awk '/^__PAYLOAD_BELOW__/{print NR+1;exit 0;}' \$0)
  tail -n+\$plstart \$0 | tar xz -C $(dirname $TMPDIR)
  cp $TMPDIR/$tmpname.repo /etc/yum.repos.d/$tmpname.repo
  yum install -y --disablerepo=* --enablerepo=$tmpname $*
  exit 0
else
  echo sudo required
  exit 1
fi
__PAYLOAD_BELOW__
INSTALLYUM_EOF

cat $tmpname.tgz >> installyum.sh
chmod +x installyum.sh

# Cleanup
rm -rf $tmpname.tgz $tmpname

# Report location of autoextracting archive
printf "\n\nAutoextracting archive is %s\n" $(pwd)/installyum.sh

################################################################################
