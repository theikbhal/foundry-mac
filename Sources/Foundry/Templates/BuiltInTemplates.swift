import Foundation

enum TemplateCatalog {
    static var builtIns: [AppTemplate] {
        [crud, pagination, search, sort, dashboard]
    }

    // MARK: - Helpers

    private static func component(
        _ type: ComponentType,
        _ name: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        props: [String: PropValue] = [:],
        events: [String: [AppAction]] = [:]
    ) -> CanvasComponent {
        ComponentSchema.makeComponent(
            type: type,
            name: name,
            x: x,
            y: y,
            width: width,
            height: height,
            props: props,
            events: events
        )
    }

    private static func page(_ name: String, _ components: [CanvasComponent]) -> TemplatePage {
        TemplatePage(name: name, components: components)
    }

    private static func query(
        _ name: String,
        _ sql: String,
        onLoad: Bool = true,
        readOnly: Bool = true
    ) -> TemplateQuery {
        TemplateQuery(name: name, sql: sql, runOnLoad: onLoad, readOnly: readOnly)
    }

    private static func options(_ pairs: [(String, String)]) -> PropValue {
        .literal(.array(pairs.map { .object(["label": .string($0.0), "value": .string($0.1)]) }))
    }

    private static let clearFormActions: [AppAction] = [
        .state("selectedCustomer", .literal(.null)),
        .setValue(component: "customerName", .literal(.string(""))),
        .setValue(component: "customerEmail", .literal(.string(""))),
        .setValue(component: "customerCompany", .literal(.string(""))),
        .setValue(component: "customerPlan", .literal(.string("Starter"))),
        .setValue(component: "customerStatus", .literal(.string("active"))),
        .setValue(component: "customerMrr", .literal(.string("")))
    ]

    private static let saveActions: [AppAction] = [
        .run("save_customer"),
        .run("get_customers"),
        .toast("Customer saved")
    ]

    // MARK: - CRUD template

    static let crud = AppTemplate(
        id: "builtin-crud",
        name: "Customer CRUD",
        summary: "Create, read, update and delete customer records with a live detail form, searchable table and SQLite-backed queries.",
        category: "Data apps",
        icon: "square.and.pencil",
        badges: ["CRUD", "Search", "Sort", "SQLite"],
        isBuiltIn: true,
        seedSQL: seedSQL,
        pages: [
            page("Customers", [
                component(.heading, "pageTitle", x: 32, y: 22, width: 700, height: 48, props: [
                    "text": .literal(.string("Customers")),
                    "size": .num(32)
                ]),
                component(.text, "pageSubtitle", x: 32, y: 72, width: 700, height: 28, props: [
                    "content": .literal(.string("A full CRUD workflow backed by a local SQLite file. Select a row to edit it, or start a new record.")),
                    "size": .num(14)
                ]),
                component(.stat, "totalStat", x: 764, y: 22, width: 194, height: 96, props: [
                    "label": .literal(.string("Customers")),
                    "value": .fx("formatNumber(queries.get_customers.data.length)"),
                    "delta": .literal(.string("in directory")),
                    "accent": .literal(.string("#6366F1"))
                ]),
                component(.stat, "mrrStat", x: 974, y: 22, width: 194, height: 96, props: [
                    "label": .literal(.string("Monthly revenue")),
                    "value": .fx("formatCurrency(sum(queries.get_customers.data, 'mrr'))"),
                    "delta": .literal(.string("recurring")),
                    "accent": .literal(.string("#10B981"))
                ]),
                component(.table, "customersTable", x: 32, y: 136, width: 704, height: 620, props: [
                    "title": .literal(.string("Customer directory")),
                    "data": .fx("queries.get_customers.data"),
                    "columns": .literal(.string("name,email,company,plan,status,mrr")),
                    "searchable": .flag(true),
                    "sortable": .flag(true),
                    "paginate": .flag(true),
                    "pageSize": .num(9),
                    "striped": .flag(true),
                    "emptyMessage": .literal(.string("No customers yet. Create the first one →"))
                ], events: [
                    "onRowClick": [
                        .state("selectedCustomer", .fx("row")),
                        .setValue(component: "customerName", .fx("row.name ?? ''")),
                        .setValue(component: "customerEmail", .fx("row.email ?? ''")),
                        .setValue(component: "customerCompany", .fx("row.company ?? ''")),
                        .setValue(component: "customerPlan", .fx("row.plan ?? 'Starter'")),
                        .setValue(component: "customerStatus", .fx("row.status ?? 'active'")),
                        .setValue(component: "customerMrr", .fx("row.mrr ?? 0"))
                    ]
                ]),
                component(.panel, "detailsPanel", x: 764, y: 136, width: 404, height: 620, props: [
                    "title": .literal(.string("Customer details")),
                    "subtitle": .literal(.string("Select a row or create a new record")),
                    "background": .literal(.string("#FFFFFF")),
                    "border": .flag(true),
                    "radius": .num(16)
                ]),
                component(.textInput, "customerName", x: 786, y: 214, width: 360, height: 64, props: [
                    "label": .literal(.string("Name")),
                    "placeholder": .literal(.string("Full name")),
                    "defaultValue": .fx("state.selectedCustomer ? state.selectedCustomer.name : ''")
                ], events: ["onSubmit": saveActions]),
                component(.textInput, "customerEmail", x: 786, y: 284, width: 360, height: 64, props: [
                    "label": .literal(.string("Email")),
                    "placeholder": .literal(.string("name@company.com")),
                    "defaultValue": .fx("state.selectedCustomer ? state.selectedCustomer.email : ''")
                ], events: ["onSubmit": saveActions]),
                component(.textInput, "customerCompany", x: 786, y: 354, width: 360, height: 64, props: [
                    "label": .literal(.string("Company")),
                    "placeholder": .literal(.string("Company name")),
                    "defaultValue": .fx("state.selectedCustomer ? state.selectedCustomer.company : ''")
                ], events: ["onSubmit": saveActions]),
                component(.select, "customerPlan", x: 786, y: 424, width: 360, height: 64, props: [
                    "label": .literal(.string("Plan")),
                    "options": options([("Starter", "Starter"), ("Growth", "Growth"), ("Scale", "Scale"), ("Enterprise", "Enterprise")]),
                    "defaultValue": .fx("state.selectedCustomer ? state.selectedCustomer.plan : 'Starter'")
                ]),
                component(.select, "customerStatus", x: 786, y: 494, width: 360, height: 64, props: [
                    "label": .literal(.string("Status")),
                    "options": options([("Active", "active"), ("Trial", "trial"), ("Churned", "churned")]),
                    "defaultValue": .fx("state.selectedCustomer ? state.selectedCustomer.status : 'active'")
                ]),
                component(.numberInput, "customerMrr", x: 786, y: 564, width: 360, height: 64, props: [
                    "label": .literal(.string("MRR ($)")),
                    "placeholder": .literal(.string("0")),
                    "defaultValue": .fx("state.selectedCustomer ? state.selectedCustomer.mrr : ''"),
                    "helper": .literal(.string("Monthly recurring revenue"))
                ], events: ["onSubmit": saveActions]),
                component(.button, "saveButton", x: 786, y: 642, width: 112, height: 38, props: [
                    "label": .literal(.string("Save")),
                    "style": .literal(.string("primary")),
                    "icon": .literal(.string("checkmark"))
                ], events: ["onClick": saveActions]),
                component(.button, "deleteButton", x: 908, y: 642, width: 96, height: 38, props: [
                    "label": .literal(.string("Delete")),
                    "style": .literal(.string("danger")),
                    "icon": .literal(.string("trash"))
                ], events: ["onClick": [
                    .run("delete_customer"),
                    .run("get_customers"),
                    .toast("Customer deleted")
                ] + clearFormActions]),
                component(.button, "newButton", x: 1014, y: 642, width: 132, height: 38, props: [
                    "label": .literal(.string("New customer")),
                    "style": .literal(.string("secondary")),
                    "icon": .literal(.string("plus"))
                ], events: ["onClick": clearFormActions])
            ])
        ],
        queries: [
            query("get_customers", #"SELECT * FROM customers ORDER BY name COLLATE NOCASE LIMIT 500;"#),
            query("save_customer", #"""
            INSERT INTO customers (id, name, email, company, plan, status, mrr, signed_up)
            VALUES (
              {{ state.selectedCustomer ? state.selectedCustomer.id : null }},
              {{ components.customerName.value }},
              {{ components.customerEmail.value }},
              {{ components.customerCompany.value }},
              {{ components.customerPlan.value }},
              {{ components.customerStatus.value }},
              {{ Number(components.customerMrr.value) || 0 }},
              COALESCE({{ state.selectedCustomer ? state.selectedCustomer.signed_up : null }}, date('now'))
            )
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              email = excluded.email,
              company = excluded.company,
              plan = excluded.plan,
              status = excluded.status,
              mrr = excluded.mrr;
            """#, onLoad: false, readOnly: false),
            query("delete_customer", #"DELETE FROM customers WHERE id = {{ state.selectedCustomer ? state.selectedCustomer.id : null }};"#, onLoad: false, readOnly: false)
        ],
        state: ["selectedCustomer": .null]
    )

    // MARK: - Pagination template

    static let pagination = AppTemplate(
        id: "builtin-pagination",
        name: "Server Pagination",
        summary: "LIMIT / OFFSET pagination driven by app state, with row counts, page-size control and disabled edge controls.",
        category: "Data apps",
        icon: "tablecells",
        badges: ["Pagination", "Bindings", "State"],
        isBuiltIn: true,
        seedSQL: seedSQL,
        pages: [
            page("Pagination", [
                component(.heading, "pageTitle", x: 32, y: 22, width: 620, height: 44, props: [
                    "text": .literal(.string("Customer directory")),
                    "size": .num(30)
                ]),
                component(.text, "pageSubtitle", x: 32, y: 70, width: 620, height: 26, props: [
                    "content": .literal(.string("Server-side pagination: each page runs a SQL query with LIMIT and OFFSET bound from app state.")),
                    "size": .num(14)
                ]),
                component(.stat, "totalStat", x: 688, y: 22, width: 180, height: 92, props: [
                    "label": .literal(.string("Total customers")),
                    "value": .fx("queries.count_customers.data[0] ? formatNumber(queries.count_customers.data[0].total) : '—'"),
                    "delta": .literal(.string("COUNT(*)")),
                    "accent": .literal(.string("#6366F1"))
                ]),
                component(.stat, "rangeStat", x: 884, y: 22, width: 148, height: 92, props: [
                    "label": .literal(.string("On this page")),
                    "value": .fx("String(queries.page_customers.rowCount)"),
                    "delta": .literal(.string("rows")),
                    "accent": .literal(.string("#0EA5E9"))
                ]),
                component(.select, "rowsPerPage", x: 1048, y: 22, width: 120, height: 64, props: [
                    "label": .literal(.string("Rows per page")),
                    "options": options([("5", "5"), ("8", "8"), ("10", "10"), ("20", "20")]),
                    "defaultValue": .fx("String(state.pageSize)")
                ], events: ["onChange": [
                    .state("pageSize", .fx("Number(components.rowsPerPage.value) || 8")),
                    .state("page", .literal(.number(1))),
                    .run("page_customers")
                ]]),
                component(.table, "customersTable", x: 32, y: 128, width: 1136, height: 508, props: [
                    "title": .literal(.string("Customers")),
                    "data": .fx("queries.page_customers.data"),
                    "columns": .literal(.string("name,email,company,plan,status,mrr")),
                    "searchable": .flag(false),
                    "sortable": .flag(false),
                    "paginate": .flag(false),
                    "striped": .flag(true),
                    "emptyMessage": .literal(.string("No rows on this page"))
                ]),
                component(.button, "prevButton", x: 32, y: 656, width: 92, height: 36, props: [
                    "label": .literal(.string("Previous")),
                    "style": .literal(.string("secondary")),
                    "icon": .literal(.string("chevron.left")),
                    "disabled": .fx("state.page <= 1")
                ], events: ["onClick": [
                    .state("page", .fx("Math.max(1, state.page - 1)")),
                    .run("page_customers")
                ]]),
                component(.button, "nextButton", x: 132, y: 656, width: 92, height: 36, props: [
                    "label": .literal(.string("Next")),
                    "style": .literal(.string("secondary")),
                    "icon": .literal(.string("chevron.right")),
                    "disabled": .fx("state.page >= Math.max(1, Math.ceil((queries.count_customers.data[0] ? queries.count_customers.data[0].total : 0) / state.pageSize))")
                ], events: ["onClick": [
                    .state("page", .fx("Math.min(Math.max(1, Math.ceil((queries.count_customers.data[0] ? queries.count_customers.data[0].total : 0) / state.pageSize)), state.page + 1)")),
                    .run("page_customers")
                ]]),
                component(.text, "pageInfo", x: 248, y: 656, width: 420, height: 36, props: [
                    "content": .fx(#""Page " + state.page + " of " + Math.max(1, Math.ceil((queries.count_customers.data[0] ? queries.count_customers.data[0].total : 0) / state.pageSize))"#),
                    "size": .num(13),
                    "color": .literal(.string("#6B7280"))
                ]),
                component(.text, "rangeInfo", x: 800, y: 656, width: 368, height: 36, props: [
                    "content": .fx(#""Ordered by name · " + state.pageSize + " rows per page""#),
                    "size": .num(13),
                    "color": .literal(.string("#9CA3AF")),
                    "align": .literal(.string("right"))
                ])
            ])
        ],
        queries: [
            query("page_customers", #"""
            SELECT * FROM customers
            ORDER BY name COLLATE NOCASE
            LIMIT {{ state.pageSize }} OFFSET {{ (state.page - 1) * state.pageSize }};
            """#),
            query("count_customers", "SELECT COUNT(*) AS total FROM customers;")
        ],
        state: [
            "page": .number(1),
            "pageSize": .number(8)
        ]
    )

    // MARK: - Search template

    static let search = AppTemplate(
        id: "builtin-search",
        name: "Search & Filter",
        summary: "A parameterized LIKE search across name, company, email and plan. Press Return or use the search button.",
        category: "Data apps",
        icon: "magnifyingglass",
        badges: ["Search", "LIKE", "Bindings"],
        isBuiltIn: true,
        seedSQL: seedSQL,
        pages: [
            page("Search", [
                component(.heading, "pageTitle", x: 32, y: 22, width: 620, height: 44, props: [
                    "text": .literal(.string("Search customers")),
                    "size": .num(30)
                ]),
                component(.text, "pageSubtitle", x: 32, y: 70, width: 700, height: 26, props: [
                    "content": .literal(.string("The query uses component values inside a LIKE filter. Try “labs”, “enterprise” or “ada”.")),
                    "size": .num(14)
                ]),
                component(.textInput, "searchInput", x: 32, y: 122, width: 520, height: 64, props: [
                    "label": .literal(.string("Search")),
                    "placeholder": .literal(.string("Name, company, email, or plan…")),
                    "defaultValue": .literal(.string(""))
                ], events: ["onSubmit": [.run("search_customers")]]),
                component(.button, "searchButton", x: 568, y: 144, width: 112, height: 38, props: [
                    "label": .literal(.string("Search")),
                    "style": .literal(.string("primary")),
                    "icon": .literal(.string("magnifyingglass"))
                ], events: ["onClick": [.run("search_customers")]]),
                component(.text, "searchHint", x: 568, y: 190, width: 380, height: 24, props: [
                    "content": .literal(.string("Runs a parameterized query — no SQL string concatenation.")),
                    "size": .num(12),
                    "color": .literal(.string("#9CA3AF"))
                ]),
                component(.stat, "resultsStat", x: 1000, y: 112, width: 168, height: 96, props: [
                    "label": .literal(.string("Results")),
                    "value": .fx("formatNumber(queries.search_customers.rowCount)"),
                    "delta": .literal(.string("matched rows")),
                    "accent": .literal(.string("#0EA5E9"))
                ]),
                component(.table, "resultsTable", x: 32, y: 232, width: 1136, height: 504, props: [
                    "title": .literal(.string("Results")),
                    "data": .fx("queries.search_customers.data"),
                    "columns": .literal(.string("name,email,company,plan,status,mrr")),
                    "searchable": .flag(false),
                    "sortable": .flag(true),
                    "paginate": .flag(true),
                    "pageSize": .num(10),
                    "striped": .flag(true),
                    "emptyMessage": .literal(.string("No matches. Try a broader term."))
                ])
            ])
        ],
        queries: [
            query("search_customers", #"""
            SELECT * FROM customers
            WHERE name LIKE '%' || {{ components.searchInput.value }} || '%'
               OR company LIKE '%' || {{ components.searchInput.value }} || '%'
               OR email LIKE '%' || {{ components.searchInput.value }} || '%'
               OR plan LIKE '%' || {{ components.searchInput.value }} || '%'
            ORDER BY name COLLATE NOCASE
            LIMIT 300;
            """#)
        ],
        state: [:]
    )

    // MARK: - Sort template

    static let sort = AppTemplate(
        id: "builtin-sort",
        name: "Server-side Sort",
        summary: "Order rows in SQL using whitelisted column bindings and a direction selector. Raw bindings demonstrate safe identifier injection.",
        category: "Data apps",
        icon: "arrow.up.arrow.down",
        badges: ["Sort", "Raw SQL", "Bindings"],
        isBuiltIn: true,
        seedSQL: seedSQL,
        pages: [
            page("Sort", [
                component(.heading, "pageTitle", x: 32, y: 22, width: 620, height: 44, props: [
                    "text": .literal(.string("Sortable customers")),
                    "size": .num(30)
                ]),
                component(.text, "pageSubtitle", x: 32, y: 70, width: 760, height: 26, props: [
                    "content": .literal(.string("Sorting happens in SQL. The ORDER BY clause is built with a raw binding and a whitelisted column list.")),
                    "size": .num(14)
                ]),
                component(.select, "sortBy", x: 32, y: 116, width: 260, height: 64, props: [
                    "label": .literal(.string("Sort by")),
                    "options": options([("Name", "name"), ("Company", "company"), ("Plan", "plan"), ("MRR", "mrr"), ("Signed up", "signed_up")]),
                    "defaultValue": .fx("state.sortKey")
                ], events: ["onChange": [
                    .state("sortKey", .fx("components.sortBy.value")),
                    .run("sort_customers")
                ]]),
                component(.select, "sortDirection", x: 308, y: 116, width: 200, height: 64, props: [
                    "label": .literal(.string("Direction")),
                    "options": options([("Ascending", "asc"), ("Descending", "desc")]),
                    "defaultValue": .fx("state.sortDir")
                ], events: ["onChange": [
                    .state("sortDir", .fx("components.sortDirection.value")),
                    .run("sort_customers")
                ]]),
                component(.button, "applyButton", x: 524, y: 138, width: 112, height: 38, props: [
                    "label": .literal(.string("Re-run")),
                    "style": .literal(.string("secondary")),
                    "icon": .literal(.string("arrow.clockwise"))
                ], events: ["onClick": [.run("sort_customers")]]),
                component(.stat, "rowsStat", x: 1000, y: 104, width: 168, height: 96, props: [
                    "label": .literal(.string("Rows returned")),
                    "value": .fx("formatNumber(queries.sort_customers.rowCount)"),
                    "delta": .fx("state.sortKey + ' · ' + state.sortDir"),
                    "accent": .literal(.string("#8B5CF6"))
                ]),
                component(.table, "sortedTable", x: 32, y: 212, width: 1136, height: 524, props: [
                    "title": .literal(.string("Sorted customers")),
                    "data": .fx("queries.sort_customers.data"),
                    "columns": .literal(.string("name,company,plan,mrr,signed_up,status")),
                    "searchable": .flag(false),
                    "sortable": .flag(false),
                    "paginate": .flag(true),
                    "pageSize": .num(12),
                    "striped": .flag(true),
                    "emptyMessage": .literal(.string("No rows returned"))
                ])
            ])
        ],
        queries: [
            query("sort_customers", #"""
            SELECT * FROM customers
            ORDER BY {{{ (["name", "company", "plan", "mrr", "signed_up"].indexOf(state.sortKey) >= 0 ? state.sortKey : "name") + " " + (state.sortDir === "desc" ? "DESC" : "ASC") }}}
            LIMIT 300;
            """#)
        ],
        state: [
            "sortKey": .string("name"),
            "sortDir": .string("asc")
        ]
    )

    // MARK: - Dashboard template

    static let dashboard = AppTemplate(
        id: "builtin-dashboard",
        name: "Analytics Dashboard",
        summary: "Live stats, a bar chart and a recent-signups table built from two SQLite queries and JavaScript transforms.",
        category: "Dashboards",
        icon: "chart.bar.xaxis",
        badges: ["Charts", "Stats", "SQL"],
        isBuiltIn: true,
        seedSQL: seedSQL,
        pages: [
            page("Overview", [
                component(.heading, "pageTitle", x: 32, y: 22, width: 620, height: 44, props: [
                    "text": .literal(.string("Overview")),
                    "size": .num(32)
                ]),
                component(.text, "pageSubtitle", x: 32, y: 72, width: 760, height: 26, props: [
                    "content": .literal(.string("Live metrics from your local SQLite database, shaped with JavaScript expressions.")),
                    "size": .num(14)
                ]),
                component(.stat, "totalStat", x: 32, y: 124, width: 272, height: 104, props: [
                    "label": .literal(.string("Total customers")),
                    "value": .fx("formatNumber(queries.list_customers.rowCount)"),
                    "delta": .literal(.string("all records")),
                    "accent": .literal(.string("#6366F1"))
                ]),
                component(.stat, "mrrStat", x: 320, y: 124, width: 272, height: 104, props: [
                    "label": .literal(.string("Monthly revenue")),
                    "value": .fx("formatCurrency(sum(queries.list_customers.data, 'mrr'))"),
                    "delta": .literal(.string("sum(mrr)")),
                    "accent": .literal(.string("#10B981"))
                ]),
                component(.stat, "activeStat", x: 608, y: 124, width: 272, height: 104, props: [
                    "label": .literal(.string("Active accounts")),
                    "value": .fx("formatNumber(queries.list_customers.data.filter(function(customer) { return customer.status === 'active'; }).length)"),
                    "delta": .literal(.string("status = active")),
                    "accent": .literal(.string("#F59E0B"))
                ]),
                component(.chart, "planChart", x: 32, y: 252, width: 716, height: 436, props: [
                    "title": .literal(.string("MRR by plan")),
                    "data": .fx("queries.mrr_by_plan.data"),
                    "xKey": .literal(.string("plan")),
                    "yKey": .literal(.string("mrr")),
                    "chartType": .literal(.string("bar")),
                    "accent": .literal(.string("#6366F1")),
                    "showGrid": .flag(true)
                ]),
                component(.table, "recentTable", x: 764, y: 252, width: 404, height: 436, props: [
                    "title": .literal(.string("Recent signups")),
                    "data": .fx("queries.list_customers.data.slice(0, 8)"),
                    "columns": .literal(.string("name,plan,mrr")),
                    "searchable": .flag(false),
                    "sortable": .flag(true),
                    "paginate": .flag(false),
                    "striped": .flag(true),
                    "emptyMessage": .literal(.string("No customers yet"))
                ])
            ])
        ],
        queries: [
            query("list_customers", "SELECT * FROM customers ORDER BY signed_up DESC LIMIT 500;"),
            query("mrr_by_plan", "SELECT plan, COUNT(*) AS customers, SUM(mrr) AS mrr FROM customers GROUP BY plan ORDER BY mrr DESC;")
        ],
        state: [:]
    )

    // MARK: - Seed data

    static let seedSQL = #"""
    CREATE TABLE IF NOT EXISTS customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      company TEXT NOT NULL,
      plan TEXT NOT NULL,
      status TEXT NOT NULL,
      mrr REAL NOT NULL DEFAULT 0,
      signed_up TEXT NOT NULL,
      notes TEXT
    );
    INSERT INTO customers (name, email, company, plan, status, mrr, signed_up, notes) VALUES
      ('Ada Lovelace', 'ada@analyticalengines.dev', 'Analytical Engines', 'Enterprise', 'active', 899, '2024-01-12', 'Annual renewal with 40 seats'),
      ('Grace Hopper', 'grace@compilerworks.io', 'Compiler Works', 'Scale', 'active', 499, '2024-02-03', 'Expansion opportunity in Q3'),
      ('Alan Turing', 'alan@enigmacloud.com', 'Enigma Cloud', 'Enterprise', 'active', 1200, '2023-11-21', 'Security review complete'),
      ('Katherine Johnson', 'katherine@orbitalmath.com', 'Orbital Math', 'Growth', 'active', 249, '2024-03-08', 'Loves the query editor'),
      ('Margaret Hamilton', 'margaret@apollostack.dev', 'Apollo Stack', 'Scale', 'active', 599, '2024-01-30', 'Requested SSO support'),
      ('Linus Torvalds', 'linus@kernelworks.org', 'Kernel Works', 'Starter', 'churned', 29, '2023-09-14', 'Moved to in-house tooling'),
      ('Barbara Liskov', 'barbara@substitutionlabs.com', 'Substitution Labs', 'Growth', 'active', 199, '2024-04-19', 'Referred two teams'),
      ('Dennis Ritchie', 'dennis@cpioneers.net', 'C Pioneers', 'Starter', 'trial', 0, '2025-01-06', 'Evaluating for 10 seats'),
      ('Radia Perlman', 'radia@spanningtree.dev', 'Spanning Tree', 'Scale', 'active', 649, '2024-05-27', 'Network analytics use case'),
      ('Donald Knuth', 'donald@texfoundry.com', 'TeX Foundry', 'Growth', 'active', 299, '2024-02-14', 'Long-time advocate'),
      ('Shafi Goldwasser', 'shafi@cryptolabs.io', 'Crypto Labs', 'Enterprise', 'active', 1500, '2023-12-11', 'Procurement approved'),
      ('Ken Thompson', 'ken@unixheritage.org', 'Unix Heritage', 'Scale', 'churned', 450, '2023-07-22', 'Budget freeze'),
      ('Frances Allen', 'frances@optimizeworks.com', 'Optimize Works', 'Growth', 'active', 279, '2024-06-04', 'Compiler insights team'),
      ('Tim Berners-Lee', 'tim@webfoundry.dev', 'Web Foundry', 'Enterprise', 'active', 980, '2024-01-08', 'Three workspaces'),
      ('Anita Borg', 'anita@systers.io', 'Systers', 'Scale', 'trial', 0, '2025-02-17', 'Trial ends next week'),
      ('John von Neumann', 'john@automata.dev', 'Automata Research', 'Growth', 'active', 349, '2024-03-29', 'Uses scheduled queries'),
      ('Hedy Lamarr', 'hedy@spectrumlabs.com', 'Spectrum Labs', 'Starter', 'active', 79, '2024-07-12', 'Upgraded from free'),
      ('Bjarne Stroustrup', 'bjarne@cpplabs.dev', 'C Plus Plus Labs', 'Scale', 'active', 729, '2024-05-02', 'Onboarded 25 builders'),
      ('Sophie Wilson', 'sophie@acornchip.com', 'Acorn Chip', 'Growth', 'active', 259, '2024-08-18', 'Hardware ops dashboards'),
      ('Niklaus Wirth', 'niklaus@pascaltools.ch', 'Pascal Tools', 'Starter', 'churned', 39, '2024-02-25', 'Went quiet after trial'),
      ('Adele Goldberg', 'adele@smalltalk.studio', 'Smalltalk Studio', 'Scale', 'active', 520, '2024-09-09', 'Custom template requests'),
      ('Guido van Rossum', 'guido@pythonic.dev', 'Pythonic', 'Enterprise', 'active', 1100, '2024-04-11', 'Python data pipelines'),
      ('James Gosling', 'james@jvmcraft.com', 'JVM Craft', 'Growth', 'trial', 0, '2025-03-02', 'Pilot with platform team'),
      ('Erna Hoover', 'erna@switchboard.io', 'Switchboard', 'Scale', 'active', 689, '2024-10-23', 'Call center analytics'),
      ('Tony Hoare', 'tony@nullsafe.dev', 'Nullsafe', 'Starter', 'active', 89, '2024-11-15', 'Solo builder'),
      ('Jean Bartik', 'jean@eniaclabs.com', 'ENIAC Labs', 'Growth', 'active', 319, '2024-12-01', 'Migrating spreadsheets'),
      ('Carol Shaw', 'carol@pixelriver.com', 'Pixel River', 'Starter', 'trial', 0, '2025-03-21', 'Game analytics trial'),
      ('Mary Wilkes', 'mary@lynxsystems.io', 'Lynx Systems', 'Scale', 'active', 580, '2024-08-30', 'Weekly ops review'),
      ('Evelyn Boyd Granville', 'evelyn@orbitsoft.com', 'Orbit Software', 'Growth', 'active', 289, '2025-01-19', 'Requested API access'),
      ('Alan Kay', 'alan@dynabook.dev', 'Dynabook Labs', 'Enterprise', 'active', 990, '2024-06-26', 'Design partner');
    """#
}
