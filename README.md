# FratmPDF

Base di un'app iOS/iPadOS (SwiftUI + PDFKit) per studiare sui PDF: lettura, annotazioni e un “Teacher” che interroga a crocette.

## Cosa c'è già

- **Libreria locale**: import di più PDF dal file picker, copia nella cartella Documents, miniature, conteggio pagine, eliminazione.
- **Lettore PDF** (`PDFKitView`): scroll continuo, zoom e selezione testo.
- **Annotazioni**:
  - evidenziazione e sottolineatura del testo selezionato (per riga, anche su più pagine);
  - scrittura a mano libera con inchiostro (colore e spessore);
  - note testuali aggiunte nel punto toccato;
  - gomma per rimuovere un'annotazione;
  - annulla ultima annotazione e salvataggio nel file originale.
- **Teacher**:
  - avatar personalizzabile (carnagione, capelli, taglio, maglia, occhiali);
  - possibilità di usare una foto, ad esempio uno screenshot della propria Memoji;
  - quiz a crocette generato dal testo del PDF (frase con parola nascosta + distrattori presi dal documento);
  - punteggio, feedback immediato e pagina da ripassare.
- **PDF di esempio** generato dall'app per provare tutto senza importare nulla.

## Struttura

```text
pdf/
  Models/
    LibraryDocument.swift      # libreria e import
    SampleDocumentFactory.swift
    StudyQuestion.swift        # modello domanda + generatore quiz
    TeacherProfile.swift       # profilo e persistenza del Teacher
  Editing/
    PDFEditorController.swift  # annotazioni, undo, salvataggio
  Views/
    LibraryView.swift
    PDFReaderView.swift
    PDFKitView.swift           # PDFView + overlay di disegno
    StudySessionView.swift     # quiz
    TeacherAvatarView.swift
    TeacherSettingsView.swift
```

## Note

- Apple non espone un'API pubblica per disegnare una Memoji dentro un'app. Per questo il Teacher ha un avatar disegnato e personalizzabile; la sezione “La tua Memoji” permette di caricare una sua immagine.
- Le domande sono generate con euristiche sul testo estratto: funzionano bene su appunti e dispense discorsive. Il passo successivo naturale è collegare un modello linguistico (es. Foundation Models) per domande più ragionate.
- Il progetto usa cartelle sincronizzate di Xcode: i nuovi file in `pdf/` entrano automaticamente nel target.

## Prossimi passi suggeriti

- PencilKit per una scrittura più naturale su iPad.
- Riordino/gestione cartelle e ricerca nella libreria.
- Domande generate per pagina/capitolo e ripasso degli errori.
- Esportazione del PDF annotato e condivisione.
- Sincronizzazione iCloud Drive.
