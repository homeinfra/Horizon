#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Regex copied from semver-tool by François Saint-Jacques
# https://github.com/fsaintjacques/semver-tool
#
# Generate version numbers based on git tags

VERSION="1.0.0"

####### Below is copied from original
NAT='0|[1-9][0-9]*'
ALPHANUM='[0-9]*[A-Za-z-][0-9A-Za-z-]*'
IDENT="$NAT|$ALPHANUM"
FIELD='[0-9A-Za-z-]+'

SEMVER_REGEX="\
^[vV]?\
($NAT)\\.($NAT)\\.($NAT)\
(\\-(${IDENT})(\\.(${IDENT}))*)?\
(\\+${FIELD}(\\.${FIELD})*)?$"
####### Above is copied from original

SHA='[0-9a-f]{4,40}'

GIT_DESCRIBE_REGEX="\
^[vV]?\
($NAT)\\.($NAT)\\.($NAT)\
(\\-((${IDENT})(\\.(${IDENT}))*))?\
(\\+(${FIELD}(\\.${FIELD})*))?\
\\-($NAT)\\-g($SHA)(\\-(dirty|broken))?$"

main() {
    parse;
}

git_version() {
    local git_describe="$(git describe --long --broken)"

    if [[ "$git_describe" =~ $GIT_DESCRIBE_REGEX ]]; then
        local major=${BASH_REMATCH[1]}
        local minor=${BASH_REMATCH[2]}
        local patch=${BASH_REMATCH[3]}
        local prere=${BASH_REMATCH[4]}
        local meta=${BASH_REMATCH[10]}
        local num=${BASH_REMATCH[12]}
        local sha=${BASH_REMATCH[13]}
        local dirt=${BASH_REMATCH[15]}

        SEM_VERSION="$major.$minor.$patch${prere}+"
        
        if [ -z $meta ]; then
            SEM_VERSION=${SEM_VERSION}${num}.${sha}
        else
            SEM_VERSION=${SEM_VERSION}${meta}.${num}.${sha}
        fi

        if [ ! -z $dirt ]; then
            SEM_VERSION=${SEM_VERSION}.${dirt}
        fi

        # Let's just make a final validation it matches the official regex
        if [[ "$SEM_VERSION" =~ $semver_regex ]]; then
            return 0
        else
            SEM_VERSION=""
            return 1
        fi
    else
        SEM_VERSION=""
        return 1
    fi
}

parse() {
	if [ $NUM_ARGS -eq 0 ]; then
		git_version; echo "$SEM_VERSION";
	else
		for i in "${ARGS[@]}"; do
			case $i in
				-h|--help)
					print_help;
					;;
				-v|--version)
					echo "$VERSION";
					;;
                --file|--file=?*)
                    local file="version.properties"
                    if [ $i != '--file' ]; then
                        file=${i##*=}
                    fi
                    git_version;
                    echo "VERSION=${SEM_VERSION}" > $file
					;;
				*)
					print_help;
					logFatal "Unexpected arguments (${NUM_ARGS}): ${ARGS[*]}"
					;;
			esac		
		done
	fi
}

print_help() {
	echo "Generates a version number based on git tag information"
    echo "This assumes you use Semantic Versioning 2.0.0 to tag your tree"
	echo ""
    echo "Usage: $ME [--file[=<file>]]"
    echo "       $ME [-h|--help|]"
    echo "       $ME [-v|--version]"
	echo ""
	echo "Options:"
	echo "  --file[=<file>] Output to a file instead of the console. If no value is given,"
    echo "                  a file named 'version.properties' will be created in the CWD"
    echo "                  with a single key=value pair. Key is 'VERSION'"
    echo "  -h,--help       Print this usage message"
	echo "  -v,--version    Print the version of this tool"
	echo ""
}

end() {
    log "== $ME Exited gracefully =="

    # If we reach here, execution completed succesfully
    exit 0
}

###########################
###### Startup logic ######
###########################

# Keep a copy of entry arguments
NUM_ARGS="$#"
ARGS=("$@")

# Path Configuration
ROOT="$(git rev-parse --show-toplevel)"
ME="$(basename $0)"
LOGGER_EXEC="$ROOT/tools/logger-shell/logger.sh"

# Import logger
. "$LOGGER_EXEC"
log "== $ME Started =="

# Call main function
main;

# Exit gracefully
end;