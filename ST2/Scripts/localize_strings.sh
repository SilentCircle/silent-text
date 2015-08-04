#find . -name "*.m" -print0 | xargs -0 genstrings -q -s NSLocalizedString -o Resources/Base.lproj/
#genstrings -a -q -s NSLocalizedString App/SilentTextStrings.h -o Resources/Base.lproj/

#the following does the same as both of the above
find . -name "*.[mh]" -print0 | xargs -0 genstrings -q -s NSLocalizedString -o Resources/Base.lproj/