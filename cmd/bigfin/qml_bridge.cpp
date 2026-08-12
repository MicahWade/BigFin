#include "qml_bridge.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QObject>
#include <QString>
#include <QFile>
#include <QDir>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QProcess>
#include <QUrl>
#include <QFileInfo>
#include <QDebug>

class NativeSessionBridge : public QObject {
    Q_OBJECT
public:
    explicit NativeSessionBridge(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE QString loadSessionsJson() {
        QString configDir = QDir::homePath() + "/.config/bigfin";
        QString configFile = configDir + "/sessions.json";
        QFile file(configFile);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            return QString::fromUtf8(file.readAll());
        }
        return "{\"activeSessionId\":\"\",\"sessions\":[]}";
    }

    Q_INVOKABLE void saveSession(const QString &serverUrl, const QString &serverName, const QString &serverVersion, const QString &userId, const QString &username, const QString &accessToken, const QString &password = "") {
        QString configDir = QDir::homePath() + "/.config/bigfin";
        QDir().mkpath(configDir);
        QString configFile = configDir + "/sessions.json";
        
        QJsonObject data;
        data["activeSessionId"] = "";
        data["sessions"] = QJsonArray();

        QFile fileRead(configFile);
        if (fileRead.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QJsonDocument doc = QJsonDocument::fromJson(fileRead.readAll());
            if (doc.isObject()) {
                data = doc.object();
            }
            fileRead.close();
        }

        QString sessId = userId + "_" + QString::number(QDateTime::currentMSecsSinceEpoch());
        QJsonArray sessions = data["sessions"].toArray();
        QJsonArray updated;

        QJsonObject newSess;
        newSess["id"] = sessId;
        newSess["serverUrl"] = serverUrl;
        newSess["serverName"] = serverName;
        newSess["serverVersion"] = serverVersion;
        newSess["userId"] = userId;
        newSess["username"] = username;
        newSess["accessToken"] = accessToken;
        newSess["password"] = password;
        newSess["lastUsed"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        updated.append(newSess);

        for (const QJsonValue &val : sessions) {
            QJsonObject s = val.toObject();
            if (s["userId"].toString() != userId || s["serverUrl"].toString() != serverUrl) {
                updated.append(s);
            }
        }

        data["sessions"] = updated;
        data["activeSessionId"] = sessId;

        QFile fileWrite(configFile);
        if (fileWrite.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
            fileWrite.write(QJsonDocument(data).toJson(QJsonDocument::Indented));
        }
    }

    Q_INVOKABLE bool switchSession(const QString &sessId) {
        QString configFile = QDir::homePath() + "/.config/bigfin/sessions.json";
        QFile fileRead(configFile);
        if (fileRead.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QJsonDocument doc = QJsonDocument::fromJson(fileRead.readAll());
            if (doc.isObject()) {
                QJsonObject data = doc.object();
                data["activeSessionId"] = sessId;
                fileRead.close();
                QFile fileWrite(configFile);
                if (fileWrite.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
                    fileWrite.write(QJsonDocument(data).toJson(QJsonDocument::Indented));
                    return true;
                }
            }
        }
        return false;
    }

    Q_INVOKABLE void deleteSession(const QString &sessId) {
        QString configFile = QDir::homePath() + "/.config/bigfin/sessions.json";
        QFile fileRead(configFile);
        if (fileRead.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QJsonDocument doc = QJsonDocument::fromJson(fileRead.readAll());
            if (doc.isObject()) {
                QJsonObject data = doc.object();
                QJsonArray sessions = data["sessions"].toArray();
                QJsonArray updated;
                for (const QJsonValue &val : sessions) {
                    QJsonObject s = val.toObject();
                    if (s["id"].toString() != sessId) {
                        updated.append(s);
                    }
                }
                data["sessions"] = updated;
                if (data["activeSessionId"].toString() == sessId) {
                    data["activeSessionId"] = updated.isEmpty() ? "" : updated.first().toObject()["id"].toString();
                }
                fileRead.close();
                QFile fileWrite(configFile);
                if (fileWrite.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
                    fileWrite.write(QJsonDocument(data).toJson(QJsonDocument::Indented));
                }
            }
        }
    }

    Q_INVOKABLE void logoutActiveSession() {
        switchSession("");
    }

    Q_INVOKABLE QString getCachedImage(const QString &url) {
        return url;
    }

    Q_INVOKABLE void reportPlaybackStart(const QString &, const QString &, const QString &, int) {}
    Q_INVOKABLE void reportPlaybackProgress(const QString &, const QString &, const QString &, int, bool, const QString &) {}
    Q_INVOKABLE void reportPlaybackStopped(const QString &, const QString &, const QString &, int) {}

    Q_INVOKABLE QString checkForUpdates() {
        QProcess proc;
        proc.start("git", QStringList() << "pull");
        if (proc.waitForFinished(15000)) {
            QString out = proc.readAllStandardOutput().trimmed();
            if (out.contains("Already up to date") || out.contains("Already up-to-date")) {
                return "Already up to date.";
            }
            return "Auto-updated: " + out;
        }
        return "Update timeout or offline.";
    }
};

#include "qml_bridge.moc"

extern "C" int LaunchNativeQtQml(const char *qml_path) {
    int argc = 1;
    char arg0[] = "bigfin";
    char *argv[] = { arg0, nullptr };

    QGuiApplication app(argc, argv);
    app.setApplicationName("bigfin");
    app.setDesktopFileName("bigfin");

    QQmlApplicationEngine engine;
    NativeSessionBridge bridge;
    engine.rootContext()->setContextProperty("SessionBridge", &bridge);

    QString pathStr = QString::fromUtf8(qml_path);
    QFileInfo fileInfo(pathStr);
    engine.addImportPath(fileInfo.absolutePath());

    engine.load(QUrl::fromLocalFile(pathStr));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return app.exec();
}
