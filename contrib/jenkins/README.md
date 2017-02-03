# CoreOS Jenkins build system

## Requirements

### Storage Requirements

CoreOS manifests are managed using git and repo, so a git server must be available to host these. An additional git repo is used by the `os-manifest` job to store a temporary manifest commit that is passed through to downstream jobs.

The jobs also require google storage buckets for storing build artifacts such as binary packages and CoreOS images.

### Jenkins Requirements

The jobs use a number of Jenkins plugins during jobs. These are:

- [Git](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin)
- [Rebuilder](https://wiki.jenkins-ci.org/display/JENKINS/Rebuild+Plugin)
- [Parameterized Trigger](https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugin)
- [Copy Artifact](https://wiki.jenkins-ci.org/display/JENKINS/Copy+Artifact+Plugin)
- [SSH Agent](https://wiki.jenkins-ci.org/display/JENKINS/SSH+Agent+Plugin)
- [Job Restrictions](https://wiki.jenkins-ci.org/display/JENKINS/Job+Restrictions+Plugin)
- [Credentials Binding](https://wiki.jenkins-ci.org/display/JENKINS/Credentials+Binding+Plugin)
- [TAP](https://wiki.jenkins-ci.org/display/JENKINS/TAP+Plugin) - for collecting test results from kola
- [Matrix Project](https://wiki.jenkins-ci.org/display/JENKINS/Matrix+Project+Plugin)

### Slave Requirements

The Jenkins jobs assume that each build slave is running CoreOS. The scripts that execute as part of the jobs use a number of tools present in CoreOS. Different host operating systems are untested.

All jobs assume that the Jenkins user on the slaves have `sudo` access, which is used by the `cork` tool.

The Jenkins slave used to execute the `os-kola-qemu` job must be run on a host that has KVM, so this slave cannot be in a VM unless it is using nested KVM, which is untested.

Most jobs use the slave label `coreos` to execute on a CoreOS system, so at least one slave (or the master) is required with this label. The `os-kola-qemu` job requires a slave with the `coreos` *and* `kvm` label.

### Secret Requirements

Some secrets are required for the various things done during the build:

- Slave SSH keys (if Jenkins slaves are used)
- git ssh key for manifest-build pushes from `os-manifest`
- google storage api key for artifact uploads and downloads

## Setup

### Running Jenkins

If you have no Jenkins instance, you can run one in a [Docker container](https://hub.docker.com/_/jenkins/) on CoreOS:

```sh
docker run -p 8080:8080 -p 50000:50000 jenkins
```

Jenkins requires a JDK installation on each slave. For amd64 slaves the Jenkins master can automatically install the JDK on the slave with either its default JDK installer or a user configured ```JDK Installer```.  For arm64 slaves the JDK must be installed manually by extracting the arm64 JDK tarball on the slave.  The JDK must either be installed to one of the Jenkins JDK search paths, ```/home/$USER/jdk``` for example, or the slave environment variable `$JAVA_HOME` must be set.  The JDK on amd64 slaves can also be setup manually in this way.

### Install plugins and jobs

Jenkins jobs in XML format are available in the [`jobs`](jobs) directory. A script called [`install.sh`](install.sh) is provided to copy jobs and install Jenkins plugins. The script will restart Jenkins as required by some plugins.  Use the environment variable ```CURL_OPTS``` to pass any additional options when running curl, for example ```CURL_OPTS='--user username:password'```.  Newer jenkins installations enable the ```"Prevent Cross Site Request Forgery exploits."``.  If your jenkins log contains entries like ```No valid crumb was included in request for //pluginManager/installNecessaryPlugins. Returning 403```, try disabling this option.

For example, if the Jenkins instance is at `http://127.0.0.1:8080`:

```sh
./install.sh http://127.0.0.1:8080
```

### Configuring CoreOS jobs

Some jobs will require modification to work correctly in any setup outside CoreOS.

- `os-manifest` will need the git url for the `manifest-builds` repo. You will also need to configure the correct SSH secret for git pushes.
- Any job using google storage will need `GOOGLE_APPLICATION_CREDENTIALS` configured, which points to a [JSON Service Account key](https://cloud.google.com/storage/docs/authentication). Additionally, these jobs will need to point to your specific google storage buckets.
- Any job signing artifacts will need `GPG_SECRET_KEY_FILE`, which is a GPG private key used to sign built artifacts.

