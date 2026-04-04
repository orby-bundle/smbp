import SwiftUI

struct UserHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL

    private let helpSections: [HelpSection] = [
        HelpSection(
            id: "search-acts",
            title: "Wyszukiwanie aktów prawnych",
            caption: "Znajdź akty prawa polskiego i Unii Europejskiej",
            rows: [
                HelpRow(
                    id: "acts-scope",
                    icon: "building.columns",
                    title: "Zakres baz",
                    description: "Karta \"Akty RP\" obejmuje Dziennik Ustaw, Monitor Polski oraz proces legislacyjny. Karta \"Prawo UE\" pozwala wyszukiwać i filtrować akty europejskie (rozporządzenia, dyrektywy, decyzje i t.p.) w językach polskim i angielskim.",
                   // tip: "Filtry daty, sygnatur i statusu znajdziesz w sekcji \"Filtry zaawansowane\"."
                ),
                HelpRow(
                    id: "acts-query",
                    icon: "text.magnifyingglass",
                    title: "Budowanie zapytania",
                    description: "Wprowadź słowa kluczowe, frazę lub numer pozycji. Aplikacja wspiera wyszukiwanie pełnotekstowe i filtrowanie po statusie obowiązywania.",
                    tip: "Skorzystaj z przycisku \"Wyczyść\" w polu wyszukiwania, aby szybko zacząć nowe zapytanie."
                ),
                HelpRow(
                    id: "acts-reading",
                    icon: "doc.richtext",
                    title: "Czytanie dokumentu",
                    description: "Otwórz wynik, aby zobaczyć treść w PDF lub przeczytaj go w HTML (dla aktów UE)."
                )
            ]
        ),
        HelpSection(
            id: "search-courts",
            title: "Wyszukiwanie orzeczeń",
            caption: "Przeglądaj orzecznictwo sądów powszechnych, administracyjnych i Sądu Najwyższego",
            rows: [
                HelpRow(
                    id: "courts-scope",
                    icon: "hammer",
                    title: "Wybór baz",
                    description: "Zakładka \"Sądy\" zawiera trzy segmenty: powszechne, administracyjne (WSA i NSA) i Sąd Najwyższy. Każda baza zachowuje własne filtry i historię wyszukiwania.",
                    //tip: "Na iPadzie możesz przełączać bazy bez utraty wyników dzięki układowi wielokolumnowemu."
                ),
                HelpRow(
                    id: "courts-filters",
                    icon: "line.3.horizontal.decrease.circle",
                    title: "Filtry specjalistyczne",
                    description: "Skorzystaj z selektorów sądu, wydziału, typu orzeczenia czy dat. Pola pomagają precyzyjnie zawęzić wyniki przy dużych bazach danych.",
                    tip: "Użyj wyszukiwarki sądów rejonowych, aby szybko znaleźć właściwą jednostkę."
                ),
                HelpRow(
                    id: "courts-results",
                    icon: "list.bullet.rectangle",
                    title: "Praca z wynikami",
                    description: "Lista orzeczeń wspiera paginację nieskończoną. Stuknij wynik, aby zobaczyć pełny skład sędziowski, tezy oraz podstawę prawną."
                )
            ]
        ),
        HelpSection(
            id: "legislative-process",
            title: "Proces legislacyjny",
            caption: "Monitoruj działania Rządu i Sejmu na każdym etapie",
            rows: [
                HelpRow(
                    id: "legis-overview",
                    icon: "scroll",
                    title: "Lista projektów",
                    description: "Zakładka \"Legislacja\" łączy źródła Rządowe i Sejmowe: widzisz projekty z wykazu prac Rady Ministrów oraz druki sejmowe z aktualnym statusem i datą wniesienia.",
                    tip: "Użyj rozwiniętych filtrów, aby szybciej uzyskać pożądane wyniki."
                ),
                HelpRow(
                    id: "legis-stages",
                    icon: "calendar.badge.clock",
                    title: "Etapy procesu",
                    description: "Widok szczegółowy prezentuje oś czasu od inicjatywy Rządu po głosowania w Sejmie i publikację. Każdy wpis zawiera dostęp do właściwych dokumentów rządowych i sejmowych.",
                    tip: "Stuknij pozycję na osi, aby rozwinąć szczegóły i pobrać powiązane dokumenty."
                ),
                HelpRow(
                    id: "legis-committees",
                    icon: "person.2",
                    title: "Prace komisji",
                    description: "Sekcja posiedzeń komisji sejmowych pokazuje zaplanowane i archiwalne terminy, przedmiot obrad, materiały Rządu przekazywane do komisji oraz nagranie posiedzenia.",
                    tip: "Dodaj posiedzenie do alertu, aby otrzymać przypomnienie o nowych materiałach."
                )
            ]
        ),
        HelpSection(
            id: "my-saved",
            title: "Moje zapisy",
            caption: "Organizuj ulubione akty i konfiguruj alerty",
            rows: [
                HelpRow(
                    id: "favorites",
                    icon: "star",
                    title: "Ulubione",
                    description: "Dodaj akt lub orzeczenie do zakładki \"Moje Akty\". Foldery pomagają grupować dokumenty tematycznie.",
                    tip: "Przytrzymaj element w widoku listy, aby szybciej dodać go do ulubionych."
                ),
                HelpRow(
                    id: "alerts",
                    icon: "bell.badge",
                    title: "Alerty",
                    description: "Zapisz zapytanie jako alert, aby otrzymywać powiadomienia o nowych dokumentach. Aplikacja sprawdza wyniki w tle, gdy ona nie jest zamknięta a Ty jesteś zalogowany. W razie odnalezienia nowych dokumentów otrzymasz powiadomienie na ekranie głównym.",
                    tip: "Alerty możesz zbiorczo włączać, wyłączać i usuwać w widoku listy."
                ),
                HelpRow(
                    id: "alert-results",
                    icon: "clock.arrow.circlepath",
                    title: "Historia wyników",
                    description: "Wejdź w alert, aby zobaczyć ostatnio znalezione dokumenty z oznaczeniem nowości. Przesunięcie w lewo umożliwia szybkie usunięcie wpisu."
                )
            ]
        ),
        HelpSection(
            id: "account",
            title: "Konto i subskrypcja",
            caption: "Zarządzaj dostępem Premium i danymi użytkownika",
            rows: [
                HelpRow(
                    id: "sign-in",
                    icon: "person.badge.shield.checkmark",
                    title: "Logowanie Apple ID",
                    description: "Zaloguj się, aby synchronizować alerty między urządzeniami i umożliwić sprawdzanie wyników w tle.",
                    tip: "Z poziomu widoku konta możesz się wylogować lub usunąć dane z serwerów."
                ),
                HelpRow(
                    id: "subscription",
                    icon: "crown",
                    title: "Subskrypcja Premium",
                    description: "Premium odblokowuje alerty oraz pełne wyszukiwanie bez ograniczeń. Z widoku ustawień przejdziesz do zarządzania subskrypcjami w App Store.",
                    tip: "Użyj opcji \"Przywróć zakupy\" jeśli korzystasz z tego samego Apple ID na kilku urządzeniach."
                ),
                HelpRow(
                    id: "billing",
                    icon: "creditcard",
                    title: "Rozliczenia",
                    description: "Płatności obsługuje App Store. Potwierdzenia zakupu i faktury znajdziesz w ustawieniach konta Apple."
                )
            ]
        ),
        HelpSection(
            id: "notifications",
            title: "Powiadomienia i tło",
            caption: "Dbaj o aktualność alertów",
            rows: [
                HelpRow(
                    id: "notifications-enable",
                    icon: "bell",
                    title: "Zezwolenia systemowe",
                    description: "Włącz powiadomienia w ustawieniach iOS, aby otrzymywać informacje o nowych wynikach. Aplikacja poprosi o dostęp przy pierwszym alertcie.",
                    tip: "Na iPadzie pamiętaj o włączeniu powiadomień dla każdego użytkownika, który korzysta z aplikacji."
                ),
                HelpRow(
                    id: "background",
                    icon: "bolt.horizontal.circle",
                    title: "Praca w tle",
                    description: "Alerty są sprawdzane okresowo, gdy urządzenie ma połączenie z siecią i użytkownik jest zalogowany. Wylogowanie zatrzymuje sprawdzanie do czasu ponownego logowania."
                ),
                HelpRow(
                    id: "troubleshooting",
                    icon: "questionmark.circle",
                    title: "Rozwiązywanie problemów",
                    description: "Jeśli powiadomienia nie docierają, upewnij się, że alert jest aktywny, urządzenie nie ma włączonego trybu skupienia, a subskrypcja jest aktualna."
                )
            ]
        )
    ]

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 20
    }

    private var gridColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: count)
    }

    private var showCloseButton: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introCard

                    quickNavigation(proxy: proxy)

                    ForEach(helpSections) { section in
                        helpSectionView(section)
                            .id(section.id)
                    }

                    supportFooter
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Pomoc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showCloseButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Zamknij") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Możliwości SM Baza Prawa")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .font(.body)
            Text("Dowiedz się o funkcjonalnościach aplikacji i jak je w pełni wykorzystać.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    private func quickNavigation(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Szybka nawigacja")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(helpSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(section.id, anchor: .top)
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: section.rows.first?.icon ?? "questionmark.circle")
                                .foregroundColor(.blue)
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    private func helpSectionView(_ section: HelpSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(section.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if let caption = section.caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(section.rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(row.title)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: row.icon)
                                .font(.body)
                                .foregroundColor(.accentColor)
                        }

                        Text(row.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let tip = row.tip {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if row.id != section.rows.last?.id {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    private var supportFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Potrzebujesz dodatkowej pomocy?")
                .font(.headline)
                .foregroundColor(.primary)

            Text("W razie pytań napisz do nas na adres bazaprawna.pl@gmail.com. Do wiadomości dołącz opis problemu i typ urządzenia - pomoże nam to zareagować szybciej.")
                .font(.subheadline)
                .foregroundColor(.secondary)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private struct HelpSection: Identifiable {
    let id: String
    let title: String
    let caption: String?
    let rows: [HelpRow]
}

private struct HelpRow: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let tip: String?

    init(id: String, icon: String, title: String, description: String, tip: String? = nil) {
        self.id = id
        self.icon = icon
        self.title = title
        self.description = description
        self.tip = tip
    }
}


