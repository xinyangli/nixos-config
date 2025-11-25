prev:
prev.owncloud-client.overrideAttrs {
  postPatch = ''
    awk -i inplace '
    /^QString Theme::oauthClientId\(\) const$/ {
        print
        getline
        print
        print "    static const QString cached = QString::fromLatin1(qgetenv(\"OWNCLOUD_OAUTH_CLIENT_ID\"));"
        print "    if (!cached.isEmpty()) { return cached; }"
        next
    }
    /^QString Theme::oauthClientSecret\(\) const$/ {
        print
        getline
        print
        print "    static const QString cached = QString::fromLatin1(qgetenv(\"OWNCLOUD_OAUTH_CLIENT_SECRET\"));"
        print "    if (!cached.isEmpty()) { return cached; }"
        next
    }
    /^QString Theme::oauthLocalhost\(\) const$/ {
        print
        getline
        print
        in_localhost = 1
        next
    }
    in_localhost && /return QStringLiteral\("http:\/\/localhost"\);/ {
        print "    return QStringLiteral(\"http://127.0.0.1\");"
        in_localhost = 0
        next
    }
    /^QPair<QString, QString> Theme::oauthOverrideAuthUrl\(\) const$/ {
        print
        getline
        print
        in_override = 1
        next
    }
    in_override && /return \{\};/ {
        print "    static const QPair<QString, QString> cached = []{"
        print "        const QByteArray a = qgetenv(\"OWNCLOUD_OAUTH_AUTH_URL\");"
        print "        const QByteArray t = qgetenv(\"OWNCLOUD_OAUTH_TOKEN_URL\");"
        print "        return (!a.isEmpty() && !t.isEmpty()) ? qMakePair(QString::fromLatin1(a), QString::fromLatin1(t)) : QPair<QString, QString>{};"
        print "    }();"
        print "    return cached;"
        in_override = 0
        next
    }
    /^QVector<quint16> Theme::oauthPorts\(\) const$/ {
        print
        getline
        print
        in_ports = 1
        next
    }
    in_ports && /\/\/ zero means a random port/ {
        next
    }
    in_ports && /return \{0\};/ {
        print "    static const QVector<quint16> cached = []{"
        print "        bool ok; quint16 p = QString::fromLatin1(qgetenv(\"OWNCLOUD_OAUTH_PORT\")).toUShort(&ok);"
        print "        return ok ? QVector<quint16>{p} : QVector<quint16>{0};"
        print "    }();"
        print "    return cached;"
        in_ports = 0
        next
    }
    {print}
    ' src/libsync/theme.cpp
  '';
}
