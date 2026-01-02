# cleanup script to remove installed packages and other artifacts

# remove installed perl in each entitery without asking
perlbrew uninstall -f bitperl

# remove the intermediate directories (except the results) if they exist    
rm -rf c-libs Bit CRoaring

# remove R packages that were installed by the install_suite.pl script
# list of R packages to remove as a variable
R_PACKAGES_TO_REMOVE=NULL
if command -v Rscript >/dev/null 2>&1; then
    echo "Removing R packages installed by install_suite.pl"
    Rscript -e "remove.packages(c($R_PACKAGES_TO_REMOVE))"
else
    echo "Rscript not found in PATH, skipping R package removal"
fi
