function jdk
    set jdk_version $argv[1]
    set -xg JAVA_HOME (/usr/libexec/java_home -v "$jdk_version")
    java -version
end
