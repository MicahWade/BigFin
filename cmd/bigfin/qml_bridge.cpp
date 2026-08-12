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
#include <QDBusConnection>

class NativeSessionBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString PlaybackStatus READ getPlaybackStatus CONSTANT)
    Q_PROPERTY(bool CanControl READ getCanControl CONSTANT)
    Q_PROPERTY(bool CanPlay READ getCanPlay CONSTANT)
    Q_PROPERTY(bool CanPause READ getCanPause CONSTANT)
    Q_PROPERTY(bool CanGoNext READ getCanGoNext CONSTANT)
    Q_PROPERTY(bool CanGoPrevious READ getCanGoPrevious CONSTANT)
    Q_PROPERTY(bool CanQuit READ getCanQuit CONSTANT)
    Q_PROPERTY(bool CanRaise READ getCanRaise CONSTANT)
    Q_PROPERTY(QString Identity READ getIdentity CONSTANT)
    Q_PROPERTY(QString DesktopEntry READ getDesktopEntry CONSTANT)

signals:
    void mediaPlayPauseRequested();
    void mediaNextRequested();
    void mediaPreviousRequested();
    void mediaStopRequested();

public:
    explicit NativeSessionBridge(QObject *parent = nullptr) : QObject(parent), m_status("Playing") {}

    QString getPlaybackStatus() const { return m_status; }
    bool getCanControl() const { return true; }
    bool getCanPlay() const { return true; }
    bool getCanPause() const { return true; }
    bool getCanGoNext() const { return true; }
    bool getCanGoPrevious() const { return true; }
    bool getCanQuit() const { return true; }
    bool getCanRaise() const { return true; }
    QString getIdentity() const { return "Bigfin Media Player"; }
    QString getDesktopEntry() const { return "bigfin"; }

    Q_INVOKABLE void PlayPause() { qDebug() << "[MPRIS Native] PlayPause received"; emit mediaPlayPauseRequested(); }
    Q_INVOKABLE void Play() { qDebug() << "[MPRIS Native] Play received"; emit mediaPlayPauseRequested(); }
    Q_INVOKABLE void Pause() { qDebug() << "[MPRIS Native] Pause received"; emit mediaPlayPauseRequested(); }
    Q_INVOKABLE void Next() { qDebug() << "[MPRIS Native] Next received"; emit mediaNextRequested(); }
    Q_INVOKABLE void Previous() { qDebug() << "[MPRIS Native] Previous received"; emit mediaPreviousRequested(); }
    Q_INVOKABLE void Stop() { qDebug() << "[MPRIS Native] Stop received"; emit mediaStopRequested(); }
    Q_INVOKABLE void Raise() {}
    Q_INVOKABLE void Quit() {}

    Q_INVOKABLE void updateMprisState(const QString &status, const QString &title = "", const QString &artist = "", const QString &album = "") {
        m_status = status;
    }

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

private:
    QString m_status;
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

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        bus.registerService("org.mpris.MediaPlayer2.bigfin");
        bus.registerObject("/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", &bridge, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllProperties);
        bus.registerObject("/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2", &bridge, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllProperties);
        qDebug() << "[MPRIS Native] Registered D-Bus service org.mpris.MediaPlayer2.bigfin";
    }

    QString pathStr = QString::fromUtf8(qml_path);
    QFileInfo fileInfo(pathStr);
    engine.addImportPath(fileInfo.absolutePath());

    engine.load(QUrl::fromLocalFile(pathStr));
    if (engine.rootObjects().isEmpty()) {
        return 1;
    }

    return app.exec();
}
