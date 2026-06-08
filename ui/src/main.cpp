#include "pontificate_core.h"

#include <QApplication>
#include <QDockWidget>
#include <QDoubleSpinBox>
#include <QFile>
#include <QFileDialog>
#include <QFrame>
#include <QFormLayout>
#include <QGraphicsDropShadowEffect>
#include <QGraphicsRectItem>
#include <QGraphicsScene>
#include <QGraphicsSimpleTextItem>
#include <QGraphicsView>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QMainWindow>
#include <QMap>
#include <QPainter>
#include <QPalette>
#include <QPushButton>
#include <QSlider>
#include <QSplitter>
#include <QStatusBar>
#include <QStyle>
#include <QSpinBox>
#include <QTabWidget>
#include <QToolBar>
#include <QVBoxLayout>
#include <QVector>

#include <algorithm>

struct TimelineClipRow {
    QString label;
    int trackIndex = 0;
    double timelineStart = 0.0;
    double duration = 5.0;
};

class CoreProject {
public:
    CoreProject() : handle_(pontificate_project_create()) {}
    explicit CoreProject(PontificateProject *handle) : handle_(handle) {}
    ~CoreProject() { pontificate_project_destroy(handle_); }

    CoreProject(const CoreProject &) = delete;
    CoreProject &operator=(const CoreProject &) = delete;

    PontificateProject *get() const { return handle_; }

    void reset(PontificateProject *handle) {
        if (handle_ == handle) {
            return;
        }
        pontificate_project_destroy(handle_);
        handle_ = handle;
    }

private:
    PontificateProject *handle_ = nullptr;
};

using SummaryFields = QMap<QString, QString>;

static QString statusName(uint32_t status) {
    switch (status) {
    case PONTIFICATE_STATUS_OK:
        return "ok";
    case PONTIFICATE_STATUS_NULL_ARGUMENT:
        return "null argument";
    case PONTIFICATE_STATUS_OUT_OF_MEMORY:
        return "out of memory";
    case PONTIFICATE_STATUS_IO_ERROR:
        return "I/O error";
    case PONTIFICATE_STATUS_UNSUPPORTED:
        return "unsupported";
    case PONTIFICATE_STATUS_DUPLICATE:
        return "duplicate";
    case PONTIFICATE_STATUS_MISSING:
        return "missing";
    case PONTIFICATE_STATUS_OUT_OF_RANGE:
        return "out of range";
    case PONTIFICATE_STATUS_BUFFER_TOO_SMALL:
        return "buffer too small";
    case PONTIFICATE_STATUS_INVALID:
        return "invalid";
    default:
        return QString("status %1").arg(status);
    }
}

static SummaryFields parseSummary(const QByteArray &summary) {
    SummaryFields fields;
    const auto parts = QString::fromUtf8(summary.constData()).split('|');
    for (const auto &part : parts) {
        const int equals = part.indexOf('=');
        if (equals > 0) {
            fields.insert(part.left(equals), part.mid(equals + 1));
        }
    }
    return fields;
}

static QByteArray readAssetSummary(PontificateProject *project, uint32_t index, uint32_t *statusOut) {
    QByteArray buffer(1024, '\0');
    uint32_t status = pontificate_project_asset_summary(project, index, buffer.data(), static_cast<uint32_t>(buffer.size()));
    if (status == PONTIFICATE_STATUS_BUFFER_TOO_SMALL) {
        buffer.fill('\0', 8192);
        status = pontificate_project_asset_summary(project, index, buffer.data(), static_cast<uint32_t>(buffer.size()));
    }
    if (statusOut) {
        *statusOut = status;
    }
    return status == PONTIFICATE_STATUS_OK ? QByteArray(buffer.constData()) : QByteArray();
}

static QByteArray readClipSummary(PontificateProject *project, uint32_t index, uint32_t *statusOut) {
    QByteArray buffer(1024, '\0');
    uint32_t status = pontificate_project_clip_summary(project, index, buffer.data(), static_cast<uint32_t>(buffer.size()));
    if (status == PONTIFICATE_STATUS_BUFFER_TOO_SMALL) {
        buffer.fill('\0', 8192);
        status = pontificate_project_clip_summary(project, index, buffer.data(), static_cast<uint32_t>(buffer.size()));
    }
    if (statusOut) {
        *statusOut = status;
    }
    return status == PONTIFICATE_STATUS_OK ? QByteArray(buffer.constData()) : QByteArray();
}

static QString assetRowText(const SummaryFields &fields) {
    const QString name = fields.value("name", "Asset");
    const QString kind = fields.value("kind", "unknown");
    const QString status = fields.value("status", "unknown");
    const QString path = fields.value("path");
    if (path.isEmpty()) {
        return QString("%1  |  %2  |  %3").arg(name, kind, status);
    }
    return QString("%1  |  %2  |  %3\n%4").arg(name, kind, status, path);
}

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
        refreshScene();
        setZoomPercent(100);
    }

    void setZoomPercent(int percent) {
        zoomPercent_ = percent;
        resetTransform();
        scale(static_cast<qreal>(percent) / 100.0, 1.0);
    }

    void setClips(const QVector<TimelineClipRow> &clips) {
        clips_ = clips;
        refreshScene();
        setZoomPercent(zoomPercent_);
    }

private:
    QGraphicsScene *scene_;
    QVector<TimelineClipRow> clips_;
    int zoomPercent_ = 100;

    void addTrackLabel(const QString &label, qreal y) {
        auto *text = scene_->addSimpleText(label);
        text->setBrush(QColor("#aeb6c4"));
        text->setPos(14, y + 13);
    }

    qreal trackY(int trackIndex) const {
        const int bounded = std::max(0, std::min(trackIndex, 3));
        return 20 + (bounded * 42);
    }

    QColor trackColor(int trackIndex) const {
        switch (trackIndex) {
        case 1:
            return QColor("#f5c26b");
        case 2:
            return QColor("#e8edf7");
        case 3:
            return QColor("#b78df0");
        default:
            return QColor("#7fd1b9");
        }
    }

    void addClip(const QString &label, const QColor &color, qreal x, qreal y, qreal w) {
        auto *rect = scene_->addRect(x, y, w, 34, QPen(QColor("#101319")), QBrush(color));
        rect->setToolTip(label);

        auto *text = scene_->addSimpleText(label);
        text->setBrush(QColor("#101319"));
        text->setPos(x + 10, y + 8);
    }

    void refreshScene() {
        scene_->clear();
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

        for (const auto &clip : clips_) {
            const qreal x = 92 + (clip.timelineStart * 38.0);
            const qreal width = std::max<qreal>(82.0, clip.duration * 38.0);
            addClip(clip.label, trackColor(clip.trackIndex), x, trackY(clip.trackIndex), width);
        }
    }
};

static QWidget *makeTimelinePane(TimelineView **timelineOut) {
    auto *pane = new QWidget;
    auto *layout = new QVBoxLayout(pane);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(8);

    auto *timeline = new TimelineView;
    if (timelineOut) {
        *timelineOut = timeline;
    }

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

    CoreProject project;

    QMainWindow window;
    window.setWindowTitle("Pontificate");
    window.resize(1280, 820);

    auto *toolbar = window.addToolBar("Editor");
    toolbar->setMovable(false);
    auto *openAction = toolbar->addAction(app.style()->standardIcon(QStyle::SP_DialogOpenButton), "Open");
    auto *saveAction = toolbar->addAction(app.style()->standardIcon(QStyle::SP_DialogSaveButton), "Save");
    auto *importAction = toolbar->addAction(app.style()->standardIcon(QStyle::SP_FileDialogDetailedView), "Import");
    auto *addToTimelineAction = toolbar->addAction(app.style()->standardIcon(QStyle::SP_ArrowRight), "Add");
    toolbar->addSeparator();
    toolbar->addAction(app.style()->standardIcon(QStyle::SP_ArrowBack), "Undo");
    toolbar->addAction(app.style()->standardIcon(QStyle::SP_ArrowForward), "Redo");
    addToTimelineAction->setEnabled(false);

    auto *library = new QListWidget;
    library->setSelectionMode(QAbstractItemView::SingleSelection);

    auto *libraryDock = new QDockWidget("Library", &window);
    libraryDock->setWidget(library);
    libraryDock->setMinimumWidth(220);
    window.addDockWidget(Qt::LeftDockWidgetArea, libraryDock);

    auto *inspectorDock = new QDockWidget("Inspector", &window);
    inspectorDock->setWidget(makeInspector());
    inspectorDock->setMinimumWidth(260);
    window.addDockWidget(Qt::RightDockWidgetArea, inspectorDock);

    int selectedClipIndex = -1;

    auto *editPanel = new QWidget;
    auto *editLayout = new QVBoxLayout(editPanel);
    editLayout->setContentsMargins(12, 12, 12, 12);
    editLayout->setSpacing(10);

    auto *selectedClipLabel = new QLabel("No clip selected");
    selectedClipLabel->setWordWrap(true);

    auto *clipIndexSpin = new QSpinBox;
    clipIndexSpin->setRange(0, 0);
    clipIndexSpin->setEnabled(false);
    clipIndexSpin->setToolTip("Current sorted clip index");

    auto *selectionForm = new QFormLayout;
    selectionForm->addRow("Clip", clipIndexSpin);

    auto *splitTime = new QDoubleSpinBox;
    splitTime->setRange(0.0, 36000.0);
    splitTime->setDecimals(3);
    splitTime->setSingleStep(0.25);
    splitTime->setValue(1.0);
    auto *splitButton = new QPushButton("Split");

    auto *trimStart = new QDoubleSpinBox;
    trimStart->setRange(0.0, 36000.0);
    trimStart->setDecimals(3);
    trimStart->setSingleStep(0.25);
    auto *trimSourceIn = new QDoubleSpinBox;
    trimSourceIn->setRange(0.0, 36000.0);
    trimSourceIn->setDecimals(3);
    trimSourceIn->setSingleStep(0.25);
    auto *trimDuration = new QDoubleSpinBox;
    trimDuration->setRange(0.001, 36000.0);
    trimDuration->setDecimals(3);
    trimDuration->setSingleStep(0.25);
    trimDuration->setValue(1.0);
    auto *trimButton = new QPushButton("Trim");

    auto *moveTrack = new QSpinBox;
    moveTrack->setRange(0, 3);
    auto *moveStart = new QDoubleSpinBox;
    moveStart->setRange(0.0, 36000.0);
    moveStart->setDecimals(3);
    moveStart->setSingleStep(0.25);
    auto *moveButton = new QPushButton("Move");

    auto *keyTime = new QDoubleSpinBox;
    keyTime->setRange(0.0, 36000.0);
    keyTime->setDecimals(3);
    keyTime->setSingleStep(0.25);
    auto *keyOpacity = new QDoubleSpinBox;
    keyOpacity->setRange(0.0, 1.0);
    keyOpacity->setDecimals(3);
    keyOpacity->setSingleStep(0.05);
    keyOpacity->setValue(1.0);
    auto *setKeyButton = new QPushButton("Set Opacity Key");
    auto *evalOpacityButton = new QPushButton("Evaluate Opacity");

    auto *splitGroup = new QGroupBox("Split");
    auto *splitForm = new QFormLayout(splitGroup);
    splitForm->addRow("Time", splitTime);
    splitForm->addRow(splitButton);

    auto *trimGroup = new QGroupBox("Trim");
    auto *trimForm = new QFormLayout(trimGroup);
    trimForm->addRow("Start", trimStart);
    trimForm->addRow("Source In", trimSourceIn);
    trimForm->addRow("Duration", trimDuration);
    trimForm->addRow(trimButton);

    auto *moveGroup = new QGroupBox("Move");
    auto *moveForm = new QFormLayout(moveGroup);
    moveForm->addRow("Track", moveTrack);
    moveForm->addRow("Start", moveStart);
    moveForm->addRow(moveButton);

    auto *keyGroup = new QGroupBox("Opacity");
    auto *keyForm = new QFormLayout(keyGroup);
    keyForm->addRow("Time", keyTime);
    keyForm->addRow("Value", keyOpacity);
    keyForm->addRow(setKeyButton);
    keyForm->addRow(evalOpacityButton);

    editLayout->addWidget(selectedClipLabel);
    editLayout->addLayout(selectionForm);
    editLayout->addWidget(splitGroup);
    editLayout->addWidget(trimGroup);
    editLayout->addWidget(moveGroup);
    editLayout->addWidget(keyGroup);
    editLayout->addStretch();

    auto *editDock = new QDockWidget("Edit", &window);
    editDock->setWidget(editPanel);
    editDock->setMinimumWidth(260);
    window.addDockWidget(Qt::RightDockWidgetArea, editDock);
    window.tabifyDockWidget(inspectorDock, editDock);
    editDock->raise();

    TimelineView *timeline = nullptr;
    auto *splitter = new QSplitter(Qt::Vertical);
    splitter->addWidget(makePreviewPane());
    splitter->addWidget(makeTimelinePane(&timeline));
    splitter->setStretchFactor(0, 3);
    splitter->setStretchFactor(1, 1);
    window.setCentralWidget(splitter);

    auto refreshTimeline = [&]() {
        QVector<TimelineClipRow> clips;
        if (project.get()) {
            const uint32_t count = pontificate_project_clip_count(project.get());
            clips.reserve(static_cast<int>(count));
            for (uint32_t index = 0; index < count; ++index) {
                uint32_t status = PONTIFICATE_STATUS_OK;
                const QByteArray summary = readClipSummary(project.get(), index, &status);
                if (status != PONTIFICATE_STATUS_OK) {
                    continue;
                }
                const SummaryFields fields = parseSummary(summary);
                TimelineClipRow clip;
                clip.label = fields.value("label", QString("Clip %1").arg(index + 1));
                clip.trackIndex = fields.value("track_index", "0").toInt();
                clip.timelineStart = fields.value("start", "0").toDouble();
                clip.duration = fields.value("duration", "5").toDouble();
                clips.append(clip);
            }
        }
        if (timeline) {
            timeline->setClips(clips);
        }
    };

    auto refreshLibrary = [&]() {
        library->clear();
        if (!project.get()) {
            addToTimelineAction->setEnabled(false);
            return;
        }
        const uint32_t count = pontificate_project_asset_count(project.get());
        for (uint32_t index = 0; index < count; ++index) {
            uint32_t status = PONTIFICATE_STATUS_OK;
            const QByteArray summary = readAssetSummary(project.get(), index, &status);
            auto *item = new QListWidgetItem;
            item->setData(Qt::UserRole, index);
            if (status == PONTIFICATE_STATUS_OK) {
                item->setText(assetRowText(parseSummary(summary)));
            } else {
                item->setText(QString("Asset %1  |  %2").arg(index + 1).arg(statusName(status)));
            }
            library->addItem(item);
        }
        addToTimelineAction->setEnabled(library->currentItem() != nullptr);
    };

    auto refreshAll = [&]() {
        refreshLibrary();
        refreshTimeline();
    };

    auto showStatus = [&](const QString &message) {
        window.statusBar()->showMessage(message, 6000);
    };

    auto selectedClipCount = [&]() -> uint32_t {
        return project.get() ? pontificate_project_clip_count(project.get()) : 0;
    };

    auto selectedClipValid = [&]() {
        return selectedClipIndex >= 0 && static_cast<uint32_t>(selectedClipIndex) < selectedClipCount();
    };

    auto updateEditControls = [&]() {
        const uint32_t count = selectedClipCount();
        const bool hasClips = count > 0;
        if (!hasClips) {
            selectedClipIndex = -1;
            selectedClipLabel->setText("No clip selected");
            clipIndexSpin->setEnabled(false);
        } else {
            if (selectedClipIndex < 0 || static_cast<uint32_t>(selectedClipIndex) >= count) {
                selectedClipIndex = static_cast<int>(count - 1);
            }
            clipIndexSpin->blockSignals(true);
            clipIndexSpin->setRange(0, static_cast<int>(count - 1));
            clipIndexSpin->setValue(selectedClipIndex);
            clipIndexSpin->setEnabled(true);
            clipIndexSpin->blockSignals(false);
            selectedClipLabel->setText(QString("Selected clip index %1 of %2").arg(selectedClipIndex).arg(count - 1));
        }

        const bool enabled = hasClips && project.get();
        splitButton->setEnabled(enabled);
        trimButton->setEnabled(enabled);
        moveButton->setEnabled(enabled);
        setKeyButton->setEnabled(enabled);
        evalOpacityButton->setEnabled(enabled);
    };
    updateEditControls();

    auto addSelectedAssetToTimeline = [&]() {
        if (!project.get()) {
            showStatus("Core project unavailable");
            return;
        }
        auto *item = library->currentItem();
        if (!item) {
            showStatus("Select a library asset first");
            return;
        }
        const uint32_t assetIndex = item->data(Qt::UserRole).toUInt();
        const uint32_t status = pontificate_project_add_asset_to_timeline(project.get(), assetIndex);
        if (status == PONTIFICATE_STATUS_OK) {
            const uint32_t count = pontificate_project_clip_count(project.get());
            selectedClipIndex = count > 0 ? static_cast<int>(count - 1) : -1;
            refreshTimeline();
            updateEditControls();
            showStatus(QString("Added asset %1 to timeline").arg(assetIndex + 1));
        } else {
            showStatus(QString("Could not add asset: %1").arg(statusName(status)));
        }
    };

    QObject::connect(library, &QListWidget::itemSelectionChanged, &window, [&]() {
        addToTimelineAction->setEnabled(project.get() && library->currentItem());
    });
    QObject::connect(library, &QListWidget::itemDoubleClicked, &window, [&](QListWidgetItem *) {
        addSelectedAssetToTimeline();
    });
    QObject::connect(addToTimelineAction, &QAction::triggered, &window, addSelectedAssetToTimeline);
    QObject::connect(clipIndexSpin, QOverload<int>::of(&QSpinBox::valueChanged), &window, [&](int value) {
        selectedClipIndex = value;
        updateEditControls();
    });

    auto runClipEdit = [&](const QString &success, const auto &operation) {
        if (!project.get()) {
            showStatus("Core project unavailable");
            return;
        }
        if (!selectedClipValid()) {
            showStatus("Select a timeline clip first");
            return;
        }
        const uint32_t status = operation(static_cast<uint32_t>(selectedClipIndex));
        if (status == PONTIFICATE_STATUS_OK) {
            refreshTimeline();
            updateEditControls();
            showStatus(success);
        } else {
            showStatus(QString("Edit failed: %1").arg(statusName(status)));
        }
    };

    QObject::connect(splitButton, &QPushButton::clicked, &window, [&]() {
        runClipEdit("Split clip", [&](uint32_t clipIndex) {
            return pontificate_project_split_clip(project.get(), clipIndex, splitTime->value());
        });
    });
    QObject::connect(trimButton, &QPushButton::clicked, &window, [&]() {
        runClipEdit("Trimmed clip", [&](uint32_t clipIndex) {
            return pontificate_project_trim_clip(
                project.get(),
                clipIndex,
                trimStart->value(),
                trimSourceIn->value(),
                trimDuration->value());
        });
    });
    QObject::connect(moveButton, &QPushButton::clicked, &window, [&]() {
        runClipEdit("Moved clip", [&](uint32_t clipIndex) {
            return pontificate_project_move_clip(
                project.get(),
                clipIndex,
                static_cast<uint32_t>(moveTrack->value()),
                moveStart->value());
        });
    });
    QObject::connect(setKeyButton, &QPushButton::clicked, &window, [&]() {
        runClipEdit("Set opacity keyframe", [&](uint32_t clipIndex) {
            return pontificate_project_set_clip_opacity_keyframe(
                project.get(),
                clipIndex,
                keyTime->value(),
                keyOpacity->value());
        });
    });
    QObject::connect(evalOpacityButton, &QPushButton::clicked, &window, [&]() {
        if (!project.get()) {
            showStatus("Core project unavailable");
            return;
        }
        if (!selectedClipValid()) {
            showStatus("Select a timeline clip first");
            return;
        }
        uint32_t status = PONTIFICATE_STATUS_OK;
        const double opacity = pontificate_project_evaluate_clip_opacity(
            project.get(),
            static_cast<uint32_t>(selectedClipIndex),
            keyTime->value(),
            &status);
        if (status == PONTIFICATE_STATUS_OK) {
            showStatus(QString("Opacity at %1s: %2").arg(keyTime->value(), 0, 'f', 3).arg(opacity, 0, 'f', 3));
        } else {
            showStatus(QString("Opacity evaluation failed: %1").arg(statusName(status)));
        }
    });

    QObject::connect(importAction, &QAction::triggered, &window, [&]() {
        if (!project.get()) {
            showStatus("Core project unavailable");
            return;
        }
        const QStringList paths = QFileDialog::getOpenFileNames(
            &window,
            "Import Media",
            QString(),
            "Media Files (*.mp4 *.mov *.mkv *.webm *.avi *.wav *.mp3 *.flac *.ogg *.m4a *.png *.jpg *.jpeg *.webp *.tif *.tiff *.srt *.vtt *.ass);;All Files (*)");
        if (paths.isEmpty()) {
            return;
        }

        int imported = 0;
        int missing = 0;
        int duplicate = 0;
        int unsupported = 0;
        int failed = 0;
        for (const auto &path : paths) {
            const QByteArray encoded = QFile::encodeName(path);
            const uint32_t status = pontificate_project_import_path(project.get(), encoded.constData());
            switch (status) {
            case PONTIFICATE_STATUS_OK:
                ++imported;
                break;
            case PONTIFICATE_STATUS_MISSING:
                ++missing;
                break;
            case PONTIFICATE_STATUS_DUPLICATE:
                ++duplicate;
                break;
            case PONTIFICATE_STATUS_UNSUPPORTED:
                ++unsupported;
                break;
            default:
                ++failed;
                break;
            }
        }
        refreshLibrary();
        showStatus(QString("Import: %1 added, %2 missing, %3 duplicate, %4 unsupported, %5 failed")
                       .arg(imported)
                       .arg(missing)
                       .arg(duplicate)
                       .arg(unsupported)
                       .arg(failed));
    });

    QObject::connect(saveAction, &QAction::triggered, &window, [&]() {
        if (!project.get()) {
            showStatus("Core project unavailable");
            return;
        }
        const QString path = QFileDialog::getSaveFileName(&window, "Save Project", QString(), "Pontificate Project (*.json);;All Files (*)");
        if (path.isEmpty()) {
            return;
        }
        const QByteArray encoded = QFile::encodeName(path);
        const uint32_t status = pontificate_project_save(project.get(), encoded.constData());
        showStatus(status == PONTIFICATE_STATUS_OK
                       ? QString("Saved %1").arg(path)
                       : QString("Save failed: %1").arg(statusName(status)));
    });

    QObject::connect(openAction, &QAction::triggered, &window, [&]() {
        const QString path = QFileDialog::getOpenFileName(&window, "Open Project", QString(), "Pontificate Project (*.json);;All Files (*)");
        if (path.isEmpty()) {
            return;
        }
        const QByteArray encoded = QFile::encodeName(path);
        PontificateProject *loaded = pontificate_project_load(encoded.constData());
        if (!loaded) {
            showStatus(QString("Open failed: %1").arg(path));
            return;
        }
        project.reset(loaded);
        refreshAll();
        updateEditControls();
        showStatus(QString("Opened %1").arg(path));
    });

    const double midpoint = pontificate_evaluate_keyframe_linear(0.0, 1.0, 0.0, 1.2, 0.6);
    if (!project.get()) {
        showStatus("Core project unavailable");
        importAction->setEnabled(false);
        saveAction->setEnabled(false);
        openAction->setEnabled(false);
    } else {
        refreshAll();
        updateEditControls();
        window.statusBar()->showMessage(QString("core %1 | %2 | midpoint opacity %3")
                                            .arg(pontificate_version())
                                            .arg(pontificate_default_project_summary())
                                            .arg(midpoint, 0, 'f', 2));
    }

    window.show();
    return app.exec();
}
