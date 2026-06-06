#include "pontificate_core.h"

#include <QApplication>
#include <QDockWidget>
#include <QDoubleSpinBox>
#include <QFrame>
#include <QGraphicsDropShadowEffect>
#include <QGraphicsRectItem>
#include <QGraphicsScene>
#include <QGraphicsSimpleTextItem>
#include <QGraphicsView>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QMainWindow>
#include <QPainter>
#include <QPalette>
#include <QPushButton>
#include <QSlider>
#include <QSplitter>
#include <QStatusBar>
#include <QStyle>
#include <QTabWidget>
#include <QToolBar>
#include <QVBoxLayout>

class TimelineView : public QGraphicsView {
public:
    explicit TimelineView(QWidget *parent = nullptr)
        : QGraphicsView(parent), scene_(new QGraphicsScene(this)) {
        setScene(scene_);
        setRenderHint(QPainter::Antialiasing);
        setFrameShape(QFrame::NoFrame);
        setMinimumHeight(210);
        setBackgroundBrush(QColor("#171a20"));
        setHorizontalScrollBarPolicy(Qt::ScrollBarAsNeeded);
        setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
        setTransformationAnchor(QGraphicsView::AnchorUnderMouse);
        setResizeAnchor(QGraphicsView::AnchorViewCenter);
        populate();
        setZoomPercent(100);
    }

    void setZoomPercent(int percent) {
        resetTransform();
        scale(static_cast<qreal>(percent) / 100.0, 1.0);
    }

private:
    QGraphicsScene *scene_;

    void addTrackLabel(const QString &label, qreal y) {
        auto *text = scene_->addSimpleText(label);
        text->setBrush(QColor("#aeb6c4"));
        text->setPos(14, y + 13);
    }

    void addClip(const QString &label, const QColor &color, qreal x, qreal y, qreal w) {
        auto *rect = scene_->addRect(x, y, w, 34, QPen(QColor("#101319")), QBrush(color));
        rect->setFlag(QGraphicsItem::ItemIsMovable);
        rect->setToolTip(label);

        auto *text = scene_->addSimpleText(label);
        text->setBrush(QColor("#101319"));
        text->setPos(x + 10, y + 8);
    }

    void populate() {
        scene_->setSceneRect(0, 0, 860, 190);

        const QColor trackLine("#252a33");
        for (int i = 0; i < 4; ++i) {
            const qreal y = 18 + (i * 42);
            scene_->addRect(72, y, 760, 34, QPen(trackLine), QBrush(QColor("#1d222b")));
        }

        addTrackLabel("V1", 18);
        addTrackLabel("A1", 60);
        addTrackLabel("SUB", 102);
        addTrackLabel("GRADE", 144);

        addClip("Opening shot", QColor("#7fd1b9"), 92, 20, 280);
        addClip("Camera audio", QColor("#f5c26b"), 92, 62, 280);
        addClip("Caption", QColor("#e8edf7"), 140, 104, 150);
        addClip("Darkroom grade", QColor("#b78df0"), 92, 146, 280);
        addClip("B-roll", QColor("#82aaff"), 388, 20, 190);
    }
};

static QWidget *makeTimelinePane() {
    auto *pane = new QWidget;
    auto *layout = new QVBoxLayout(pane);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(8);

    auto *timeline = new TimelineView;

    auto *controls = new QWidget;
    auto *controlLayout = new QHBoxLayout(controls);
    controlLayout->setContentsMargins(12, 0, 12, 10);
    controlLayout->setSpacing(8);

    auto *zoomOut = new QPushButton("-");
    zoomOut->setFixedSize(28, 28);
    zoomOut->setToolTip("Zoom out");

    auto *zoomSlider = new QSlider(Qt::Horizontal);
    zoomSlider->setRange(25, 400);
    zoomSlider->setSingleStep(5);
    zoomSlider->setPageStep(25);
    zoomSlider->setValue(100);
    zoomSlider->setFixedWidth(220);
    zoomSlider->setToolTip("Timeline zoom");

    auto *zoomIn = new QPushButton("+");
    zoomIn->setFixedSize(28, 28);
    zoomIn->setToolTip("Zoom in");

    auto *zoomValue = new QLabel("100%");
    zoomValue->setMinimumWidth(48);
    zoomValue->setAlignment(Qt::AlignRight | Qt::AlignVCenter);

    QObject::connect(zoomOut, &QPushButton::clicked, zoomSlider, [zoomSlider]() {
        zoomSlider->setValue(zoomSlider->value() - 25);
    });
    QObject::connect(zoomIn, &QPushButton::clicked, zoomSlider, [zoomSlider]() {
        zoomSlider->setValue(zoomSlider->value() + 25);
    });
    QObject::connect(zoomSlider, &QSlider::valueChanged, timeline, [timeline, zoomValue](int value) {
        timeline->setZoomPercent(value);
        zoomValue->setText(QString("%1%").arg(value));
    });

    controlLayout->addStretch();
    controlLayout->addWidget(zoomOut);
    controlLayout->addWidget(zoomSlider);
    controlLayout->addWidget(zoomIn);
    controlLayout->addWidget(zoomValue);

    layout->addWidget(timeline, 1);
    layout->addWidget(controls);
    return pane;
}

static QWidget *makePreviewPane() {
    auto *pane = new QWidget;
    auto *layout = new QVBoxLayout(pane);
    layout->setContentsMargins(14, 14, 14, 14);
    layout->setSpacing(10);

    auto *preview = new QLabel("PONTIFICATE");
    preview->setAlignment(Qt::AlignCenter);
    preview->setMinimumHeight(330);
    preview->setStyleSheet(
        "QLabel {"
        "background: #08090d;"
        "color: #f4f7fb;"
        "font-size: 34px;"
        "font-weight: 700;"
        "border: 1px solid #242936;"
        "}");

    auto *shadow = new QGraphicsDropShadowEffect(preview);
    shadow->setBlurRadius(28);
    shadow->setColor(QColor(0, 0, 0, 120));
    shadow->setOffset(0, 8);
    preview->setGraphicsEffect(shadow);

    auto *transport = new QWidget;
    auto *transportLayout = new QHBoxLayout(transport);
    transportLayout->setContentsMargins(0, 0, 0, 0);
    transportLayout->addStretch();

    const QList<QStyle::StandardPixmap> icons = {
        QStyle::SP_MediaSkipBackward,
        QStyle::SP_MediaPlay,
        QStyle::SP_MediaSkipForward,
    };

    for (const auto icon : icons) {
        auto *button = new QPushButton;
        button->setIcon(QApplication::style()->standardIcon(icon));
        button->setFixedSize(34, 30);
        transportLayout->addWidget(button);
    }

    transportLayout->addStretch();
    layout->addWidget(preview, 1);
    layout->addWidget(transport);
    return pane;
}

static QWidget *makeInspector() {
    auto *tabs = new QTabWidget;

    auto *transform = new QWidget;
    auto *transformLayout = new QVBoxLayout(transform);
    transformLayout->setSpacing(12);

    auto *scale = new QDoubleSpinBox;
    scale->setRange(0.05, 8.0);
    scale->setSingleStep(0.05);
    scale->setValue(1.0);

    auto *opacity = new QSlider(Qt::Horizontal);
    opacity->setRange(0, 100);
    opacity->setValue(100);

    transformLayout->addWidget(new QLabel("Scale"));
    transformLayout->addWidget(scale);
    transformLayout->addWidget(new QLabel("Opacity"));
    transformLayout->addWidget(opacity);
    transformLayout->addStretch();

    auto *color = new QWidget;
    auto *colorLayout = new QVBoxLayout(color);
    const QStringList colorControls = {"Exposure", "Contrast", "Saturation", "Temperature"};
    for (const auto &label : colorControls) {
        auto *slider = new QSlider(Qt::Horizontal);
        slider->setRange(-100, 100);
        slider->setValue(0);
        colorLayout->addWidget(new QLabel(label));
        colorLayout->addWidget(slider);
    }
    colorLayout->addStretch();

    auto *subtitles = new QWidget;
    auto *subtitleLayout = new QVBoxLayout(subtitles);
    subtitleLayout->addWidget(new QLabel("Font"));
    auto *fontButton = new QPushButton("Inter");
    subtitleLayout->addWidget(fontButton);
    subtitleLayout->addWidget(new QLabel("Size"));
    auto *size = new QSlider(Qt::Horizontal);
    size->setRange(18, 96);
    size->setValue(42);
    subtitleLayout->addWidget(size);
    subtitleLayout->addStretch();

    tabs->addTab(transform, "Transform");
    tabs->addTab(color, "Color");
    tabs->addTab(subtitles, "Subtitles");
    return tabs;
}

static void applyPalette(QApplication &app) {
    QPalette palette;
    palette.setColor(QPalette::Window, QColor("#20242c"));
    palette.setColor(QPalette::WindowText, QColor("#e7ebf2"));
    palette.setColor(QPalette::Base, QColor("#151820"));
    palette.setColor(QPalette::AlternateBase, QColor("#20242c"));
    palette.setColor(QPalette::ToolTipBase, QColor("#f4f7fb"));
    palette.setColor(QPalette::ToolTipText, QColor("#171a20"));
    palette.setColor(QPalette::Text, QColor("#e7ebf2"));
    palette.setColor(QPalette::Button, QColor("#2a303a"));
    palette.setColor(QPalette::ButtonText, QColor("#e7ebf2"));
    palette.setColor(QPalette::Highlight, QColor("#7fd1b9"));
    palette.setColor(QPalette::HighlightedText, QColor("#0c1116"));
    app.setPalette(palette);
}

int main(int argc, char *argv[]) {
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QApplication app(argc, argv);
    app.setApplicationName("Pontificate");
    applyPalette(app);

    QMainWindow window;
    window.setWindowTitle("Pontificate");
    window.resize(1280, 820);

    auto *toolbar = window.addToolBar("Editor");
    toolbar->setMovable(false);
    toolbar->addAction(app.style()->standardIcon(QStyle::SP_DialogOpenButton), "Open");
    toolbar->addAction(app.style()->standardIcon(QStyle::SP_DialogSaveButton), "Save");
    toolbar->addSeparator();
    toolbar->addAction(app.style()->standardIcon(QStyle::SP_ArrowBack), "Undo");
    toolbar->addAction(app.style()->standardIcon(QStyle::SP_ArrowForward), "Redo");

    auto *library = new QListWidget;
    library->addItems({"Opening shot", "Camera audio", "Darkroom grade", "Caption track"});

    auto *libraryDock = new QDockWidget("Library", &window);
    libraryDock->setWidget(library);
    libraryDock->setMinimumWidth(220);
    window.addDockWidget(Qt::LeftDockWidgetArea, libraryDock);

    auto *inspectorDock = new QDockWidget("Inspector", &window);
    inspectorDock->setWidget(makeInspector());
    inspectorDock->setMinimumWidth(260);
    window.addDockWidget(Qt::RightDockWidgetArea, inspectorDock);

    auto *splitter = new QSplitter(Qt::Vertical);
    splitter->addWidget(makePreviewPane());
    splitter->addWidget(makeTimelinePane());
    splitter->setStretchFactor(0, 3);
    splitter->setStretchFactor(1, 1);
    window.setCentralWidget(splitter);

    const double midpoint = pontificate_evaluate_keyframe_linear(0.0, 1.0, 0.0, 1.2, 0.6);
    window.statusBar()->showMessage(QString("core %1 | %2 | midpoint opacity %3")
                                        .arg(pontificate_version())
                                        .arg(pontificate_default_project_summary())
                                        .arg(midpoint, 0, 'f', 2));

    window.show();
    return app.exec();
}
