#ifndef CONTENTDATABASE_H
#define CONTENTDATABASE_H

#include <QSqlDatabase>
#include <QSqlDriver>
#include <QSqlError>
#include <QSqlQuery>

#include <QString>
#include <QObject>

enum ContentFormat {DOCBOOK, HTML};

class ContentDatabase : public QObject {
   Q_OBJECT

   Q_PROPERTY(QStringList completionModel MEMBER m_completionModel NOTIFY completionsChanged)

   QStringList m_completionModel;

public:
    explicit ContentDatabase (QObject* parent = 0);

    void connect();

    Q_INVOKABLE // Allows to invoke this method from QML.
    QString normalize(QString searchTerm);

    Q_INVOKABLE // Allows to invoke this method from QML.
    void updateCompletions(QString nameFragments, int limit);

    QString contentAsDocbook(QString barcode);

    Q_INVOKABLE // Allows to invoke this method from QML.
    QString content(QString searchTerm, ContentFormat format = ContentFormat::HTML);

    QString literature(QString searchTerm);

signals:
    void completionsChanged();
};

#endif // CONTENTDATABASE_H
