module polyglotscan.core.version_;

enum appName = "PolyglotScan";
enum appVersion = "0.1.0";
enum appBuild = "dev";
enum appHomepage = "https://github.com/PolyglotScan/polyglotscan";

string versionLine()
{
    return appName ~ " " ~ appVersion ~ "-" ~ appBuild;
}
