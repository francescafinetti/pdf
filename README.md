# FratmPDF

App iOS/iPadOS (SwiftUI + PDFKit) per studiare sui PDF: lettura, annotazioni, scrittura a mano con PencilKit e un “Teacher” che interroga a crocette, con ripasso automatico degli errori.

## Cosa c'è

### Libreria
- Import di più PDF dal file picker, copia nella cartella Documents
- Miniature, conteggio pagine, eliminazione
- PDF di esempio generato dall'app per provare tutto

### Lettura e annotazioni
- Selezione testo, **evidenziazione** e **sottolineatura** riga per riga (anche su più pagine)
- **Scrittura a mano con PencilKit**: un canvas per pagina, fluido con Apple Pencil (e con il dito), con colori, gomma dedicata e undo
- **Note testuali** posizionate sul punto toccato
- Gomma per le annotazioni PDF, annulla ultima azione e salvataggio del PDF
- I disegni PencilKit sono salvati per pagina in un file di supporto (`Application Support/FratmPDF/Drawings`) e ricaricati alla riapertura

### Teacher
- Avatar memoji-inspired personalizzabile (carnagione, capelli, taglio, maglia, occhiali)
- Possibilità di usare una foto, ad esempio uno screenshot della propria Memoji
- **Domande a crocette** generate dal testo del PDF:
  - con **Foundation Models** su dispositivi con Apple Intelligence attiva (domande scritte dal modello on-device);
  - con un generatore euristico di fallback quando Apple Intelligence non è disponibile (es. simulatore).
- Feedback immediato, punteggio e pagina da ripassare

### Ripasso automatico degli errori
- Ogni risposta sbagliata viene salvata nel **Ripasso**
- Gli errori sono subito disponibili nella libreria e tornano con scadenze crescenti (1 giorno, 3 giorni, poi spariscono dopo 3 risposte corrette)
- Sessione di ripasso dedicata con chip del documento di origine

## Struttura

```text
pdf/
  Models/
    LibraryDocument.swift
    SampleDocumentFactory.swift
    StudyQuestion.swift
    FoundationModelsQuizGenerator.swift  # domande AI on-device
    ReviewStore.swift                    # errori + spaced repetition
    TeacherProfile.swift
  Editing/
    PDFEditorController.swift
    PencilDrawingStore.swift             # persistenza disegni per pagina
    PencilOverlayCoordinator.swift       # PKCanvasView sopra PDFKit
  Views/
    LibraryView.swift
    PDFReaderView.swift
    PDFKitView.swift
    StudySessionView.swift
    TeacherAvatarView.swift
    TeacherSettingsView.swift
```

## Note tecniche

- **Memoji**: Apple non espone un'API pubblica per disegnare una Memoji dentro un'app. Il Teacher ha un avatar disegnato e personalizzabile; la sezione “La tua Memoji” permette di caricare una sua immagine.
- **PencilKit + PDFKit**: l'overlay usa `PDFPageOverlayViewProvider`. Quando si attiva la penna, `PDFView.isInMarkupMode` passa a `true` così i tocchi arrivano al canvas; con lo strumento “Seleziona testo” torna la selezione PDF. Per scorrere mentre si disegna si può tornare a “Seleziona testo”.
- **Persistenza dei disegni**: i tratti PencilKit non sono ancora “bruciati” dentro il PDF (per quello servirebbe una fase di export dedicata); sono salvati per pagina e ricaricati fedelmente dall'app.
- **Foundation Models**: disponibile da iOS 26 sui dispositivi compatibili con Apple Intelligence. Sul simulatore il modello può risultare disponibile ma andare in timeout, quindi viene usato direttamente il fallback euristico.
- Il progetto usa cartelle sincronizzate di Xcode: i nuovi file in `pdf/` entrano automaticamente nel target.

## Prossimi passi suggeriti

- Export del PDF con i disegni PencilKit “bruciati” dentro (annotations burn-in) e condivisione
- Tool picker PencilKit completo (penna/matita/evidenziatore) e regolazione spessore
- Domande AI per capitolo/pagina e spiegazioni della risposta
- Sincronizzazione iCloud Drive e cartelle nella libreria
- Statistiche di ripasso e promemoria
