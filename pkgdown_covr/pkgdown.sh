#!/bin/sh -l

echo '\nGetting the code...\n'
git clone https://$2@github.com/$1 check
cd check

git config user.name "Checklist bot"
git config user.email "checklist@inbo.be"
git config advice.detachedHead false
git checkout $GITHUB_SHA

export CI=TRUE
export CODECOV_TOKEN=$4

cd $3

if [ ! -z "$5" ]; then
  apt-get update
  apt-get install -y --no-install-recommends $5
fi

echo '\nTrying to install the package...\n'
Rscript --no-save --no-restore -e 'remotes::install_local(dependencies = TRUE, force = TRUE)'
if [ $? -ne 0 ]; then
  echo '\nBuilding the package failed. Please check the error message above.\n';
  exit 1
fi

echo '\nChecking code coverage...\n'
Rscript --no-save --no-restore -e 'result <- covr::codecov(quiet = FALSE, commit="'$GITHUB_SHA'"); message(result$message)'
if [ $? -ne 0 ]; then
  echo '\nChecking code coverage failed. Please check the error message above.\n';
  exit 1
fi

echo '\nBuilding pkgdown website...\n'
Rscript --no-save --no-restore -e 'pkgdown::build_site()'

echo "Action:" $GITHUB_ACTIONS
echo "Event name:" $GITHUB_EVENT_NAME
echo "Ref:" $GITHUB_REF
if [ "$GITHUB_ACTIONS" != "true" ]; then
  echo '\nNot updating pkgdown site, because not a GitHub action.';
elif [ "$GITHUB_EVENT_NAME" != "push" ]; then
  echo '\nNot updating pkgdown site, because not a push event.';
elif [ "$GITHUB_REF" != "refs/heads/main" ] && [ "$GITHUB_REF" != "refs/heads/master" ]; then
  echo '\nNot updating pkgdown site, because not on main or master.';
else
  echo '\nUpdating pkgdown site...\n';
  if [ "$GITHUB_REF" != "refs/heads/master" ]; then
    git checkout main
  else
    git checkout master
  fi

  echo '\nPush pkgdown website...\n'
  cp -R docs ../docs
  if [ -z  "$(git branch -r | grep origin/gh-pages)" ]; then
    git checkout --orphan gh-pages
    git rm -rf --quiet .
    git commit --allow-empty -m "Initializing gh-pages branch"
  else
    git checkout -b gh-pages
    git rm -rf --quiet .
    rm -R *
  fi
  cp -R ../docs/. .
  git add --all
  git commit --amend -m "Automated update of gh-pages website"
  git push --force --set-upstream origin gh-pages
fi
