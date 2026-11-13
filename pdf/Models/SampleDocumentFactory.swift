//
//  SampleDocumentFactory.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation
import UIKit

/// Builds a small PDF used to try the app without importing anything.
enum SampleDocumentFactory {
    static func makePDFData() -> Data? {
        let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let pages: [[String]] = [
            [
                "La memoria a lungo termine si costruisce con il recupero attivo: chiudere il libro e provare a spiegare un concetto a voce alta è molto più efficace di una rilettura passiva.",
                "Il ripasso dilazionato distribuisce lo studio su più giorni e sfrutta l'effetto spacing, che migliora la ritenzione delle informazioni.",
                "Le domande a crocette sono uno strumento di autovalutazione: ti obbligano a riconoscere la risposta corretta e a individuare subito le lacune.",
                "Durante la lettura di un PDF, sottolinea solo le idee chiave e aggiungi note brevi con parole tue, così il materiale diventa più personale e facile da ricordare."
            ],
            [
                "Il metodo Cornell divide la pagina in tre aree: appunti, parole chiave e riassunto finale.",
                "Prima di un esame, alterna sessioni di studio da cinquanta minuti a pause brevi di dieci minuti per mantenere alta la concentrazione.",
                "Dormire almeno sette ore dopo lo studio consolida i ricordi e prepara il cervello a recuperare le informazioni il giorno successivo.",
                "Il tuo Teacher usa il testo del documento per creare domande a crocette e verificare se hai davvero capito i passaggi principali.",
                "Buono studio e in bocca al lupo per i tuoi esami."
            ]
        ]

        return renderer.pdfData { context in
            for (index, paragraphs) in pages.enumerated() {
                context.beginPage()
                drawPage(paragraphs: paragraphs, pageNumber: index + 1, in: pageBounds)
            }
        }
    }

    private static func drawPage(paragraphs: [String], pageNumber: Int, in bounds: CGRect) {
        let margin: CGFloat = 56

        NSString(string: "Studiare meglio con FratmPDF").draw(
            at: CGPoint(x: margin, y: margin),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        )

        var cursorY = margin + 52

        for paragraph in paragraphs {
            let width = bounds.width - margin * 2
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let textRect = CGRect(x: margin, y: cursorY, width: width, height: 300)
            let bounding = (paragraph as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )

            (paragraph as NSString).draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )

            cursorY += bounding.height + 18
        }

        NSString(string: "Pagina \(pageNumber)").draw(
            at: CGPoint(x: margin, y: bounds.height - margin),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
    }
}
