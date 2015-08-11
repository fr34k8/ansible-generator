#!/bin/sh

##Always exit on $? -ne 0
set -e
##

##### Create a release for a project managed with a Git repository #####



### Functions ###

# Confirm dialog for user interactions
# Usage: confirm "Question?"
# Returns: 0 = true, 1 = false
confirm() {
  read -r -p "$1 [y/n] " response
  case $response in
    [yY][eE][sS]|[yY])
      return 0;;
    *)
      return 1;;
  esac
}

### Display usage message
if [ $# -ne 2 ]; then
  >&2 echo "Usage:    $0 'ReleaseVersionNumber' 'One line summary of changes for this release'"
  >&2 echo "Example:  $0 '1.0.0' 'Added initalization checks'"
  exit 1
fi



### Initialize the variables and settings ###
#Variables
FILENAME_TMPCHANGELOG='releasescripttmp_CHANGELOG.md'

# Some information must be provided with command line args
RELEASE_VERSION=$1
SHORT_SUMMARY=$2

# Fetch Git remote inormation
git fetch origin --tags

# Some information can be detected
LAST_VERSION=$( git tag -l | tail -n 1 )
REPOSITORY_NAME=$( git remote show -n origin | grep Fetch | sed 's#.*/##' | sed 's/\.git//' )
RELEASE_BRANCH="release/${RELEASE_VERSION}"

# Confirm or exit
echo
echo "Settings for the release to be created:"
echo "  Version of last release:  ${LAST_VERSION}"
echo "  Version of new release:   ${RELEASE_VERSION}"
echo "  Name of Git repository:   ${REPOSITORY_NAME}"
echo "  Summary text for release: ${SHORT_SUMMARY}"
if ! confirm "Continue with these settings?"; then
  exit 1
fi



### Perform release ###

echo
echo "Checkout and pull next branch"
git checkout next
git pull origin next

echo
echo "Checkout new release branch"
git checkout -b ${RELEASE_BRANCH}

echo
echo "Write VERSION file"
echo ${RELEASE_VERSION} > VERSION

echo
echo "Add release information to CHANGELOG.md file"

cat CHANGELOG.md > $FILENAME_TMPCHANGELOG
echo "# ${RELEASE_VERSION}" > CHANGELOG.md
echo "" >> CHANGELOG.md

if [ -n ${LAST_VERSION} ]; then
  git shortlog --no-merges next --not ${LAST_VERSION} | sed -e '/^[ \t]/s#^[ \t]*#* #' | perl -pe 's/:$/:\n/g' >> CHANGELOG.md
  cat $FILENAME_TMPCHANGELOG >> CHANGELOG.md
else
  git shortlog --no-merges next | sed -e '/^[ \t]/s#^[ \t]*#* #' | perl -pe 's/:$/:\n/g' >> CHANGELOG.md
  cat $FILENAME_TMPCHANGELOG >> CHANGELOG.md
fi
echo "Please verify and adjust version information that was appended to CHANGELOG.md file"
echo "Diff looks like this:"
echo
echo '###### Diff start ######'

## Disable exit on $? -ne 0 for the diff command, since it returns $? == 1 if a diff was found
set +e
diff -u $FILENAME_TMPCHANGELOG CHANGELOG.md
set -e

echo '###### Diff end ######'
echo
echo "In case this is not correct, press ctrl+z to pause this script, adjust CHANGELOG.md and get back using the fg command"
while ! confirm "Continue?"; do
  echo "And now?"
done

echo
echo "Commit generated release information"
rm -f $FILENAME_TMPCHANGELOG
git add VERSION
git add CHANGELOG.md
git commit -m "${REPOSITORY_NAME} ${RELEASE_VERSION}: ${SHORT_SUMMARY}"

echo
echo "Checkout and pull master branch"
git checkout master
git pull origin master

echo
echo "Merge release branch to master branch"
git merge --no-ff --log --no-edit ${RELEASE_BRANCH}

echo
echo "Create release tag"
git tag -a ${RELEASE_VERSION} -m "${REPOSITORY_NAME} ${RELEASE_VERSION}: ${SHORT_SUMMARY}"

echo
echo "Merge release branch to next branch"
git checkout next
git merge ${RELEASE_BRANCH}

echo
echo "Delete release branch - it's obsolete now"
git branch -d ${RELEASE_BRANCH}

echo
echo "Push all changes to remote repository"
git push origin master next ${RELEASE_VERSION}
exit 0
