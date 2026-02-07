package org.kockpit.audit.stream.opensearch;

public class OpensearchHelper {

    public static String getIndexPrefix(String domain, String indexSuffix, String env, int ttl) {
        return domain + "-" + indexSuffix + "-" + env + "-ttl" + ttl + "d";
    }

    public static String getAliasWrite(String domain, String indexSuffix, String env, int ttl) {
        return domain + "-" + indexSuffix + "-" + env + "-ttl" + ttl + "d-write";
    }

    public static String getAliasRead(String domain, String indexSuffix, String env) {
        return domain + "-" + indexSuffix + "-" + env + "-read";
    }
}
