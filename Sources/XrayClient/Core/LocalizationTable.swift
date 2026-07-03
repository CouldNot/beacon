import Foundation

extension Loc {
    /// Translation table: English key → [language code: translation].
    /// Languages: ru, zh, es, hi, ar, fr, pt, de, ja, id, tr.
    static let table: [String: [String: String]] = [

        // MARK: Connection status
        "Connected": [
            "ru": "Подключено", "zh": "已连接", "es": "Conectado", "hi": "कनेक्टेड",
            "ar": "متصل", "fr": "Connecté", "pt": "Conectado", "de": "Verbunden",
            "ja": "接続済み", "id": "Terhubung", "tr": "Bağlandı"],
        "Connecting…": [
            "ru": "Подключение…", "zh": "连接中…", "es": "Conectando…", "hi": "कनेक्ट हो रहा है…",
            "ar": "جارٍ الاتصال…", "fr": "Connexion…", "pt": "Conectando…", "de": "Verbinde…",
            "ja": "接続中…", "id": "Menghubungkan…", "tr": "Bağlanıyor…"],
        "Disconnected": [
            "ru": "Отключено", "zh": "已断开", "es": "Desconectado", "hi": "डिस्कनेक्टेड",
            "ar": "غير متصل", "fr": "Déconnecté", "pt": "Desconectado", "de": "Getrennt",
            "ja": "切断済み", "id": "Terputus", "tr": "Bağlantı kesildi"],

        // MARK: Buttons / actions
        "Connect": [
            "ru": "Подключить", "zh": "连接", "es": "Conectar", "hi": "कनेक्ट",
            "ar": "اتصال", "fr": "Connecter", "pt": "Conectar", "de": "Verbinden",
            "ja": "接続", "id": "Hubungkan", "tr": "Bağlan"],
        "Disconnect": [
            "ru": "Отключить", "zh": "断开", "es": "Desconectar", "hi": "डिस्कनेक्ट",
            "ar": "قطع الاتصال", "fr": "Déconnecter", "pt": "Desconectar", "de": "Trennen",
            "ja": "切断", "id": "Putuskan", "tr": "Bağlantıyı kes"],
        "Select a server": [
            "ru": "Выберите сервер", "zh": "选择服务器", "es": "Selecciona un servidor",
            "hi": "सर्वर चुनें", "ar": "اختر خادمًا", "fr": "Choisir un serveur",
            "pt": "Selecione um servidor", "de": "Server wählen", "ja": "サーバーを選択",
            "id": "Pilih server", "tr": "Bir sunucu seçin"],
        "Cancel": [
            "ru": "Отмена", "zh": "取消", "es": "Cancelar", "hi": "रद्द करें",
            "ar": "إلغاء", "fr": "Annuler", "pt": "Cancelar", "de": "Abbrechen",
            "ja": "キャンセル", "id": "Batal", "tr": "İptal"],
        "Done": [
            "ru": "Готово", "zh": "完成", "es": "Listo", "hi": "हो गया",
            "ar": "تم", "fr": "Terminé", "pt": "Concluído", "de": "Fertig",
            "ja": "完了", "id": "Selesai", "tr": "Bitti"],
        "Add": [
            "ru": "Добавить", "zh": "添加", "es": "Añadir", "hi": "जोड़ें",
            "ar": "إضافة", "fr": "Ajouter", "pt": "Adicionar", "de": "Hinzufügen",
            "ja": "追加", "id": "Tambah", "tr": "Ekle"],
        "Remove": [
            "ru": "Удалить", "zh": "移除", "es": "Eliminar", "hi": "हटाएं",
            "ar": "إزالة", "fr": "Supprimer", "pt": "Remover", "de": "Entfernen",
            "ja": "削除", "id": "Hapus", "tr": "Kaldır"],
        "Delete": [
            "ru": "Удалить", "zh": "删除", "es": "Borrar", "hi": "हटाएं",
            "ar": "حذف", "fr": "Supprimer", "pt": "Excluir", "de": "Löschen",
            "ja": "削除", "id": "Hapus", "tr": "Sil"],
        "Fetch": [
            "ru": "Загрузить", "zh": "获取", "es": "Obtener", "hi": "लाएं",
            "ar": "جلب", "fr": "Récupérer", "pt": "Buscar", "de": "Abrufen",
            "ja": "取得", "id": "Ambil", "tr": "Getir"],
        "Save": [
            "ru": "Сохранить", "zh": "保存", "es": "Guardar", "hi": "सहेजें",
            "ar": "حفظ", "fr": "Enregistrer", "pt": "Salvar", "de": "Speichern",
            "ja": "保存", "id": "Simpan", "tr": "Kaydet"],

        // MARK: Toolbar / footer
        "Subscription": [
            "ru": "Подписка", "zh": "订阅", "es": "Suscripción", "hi": "सदस्यता",
            "ar": "اشتراك", "fr": "Abonnement", "pt": "Assinatura", "de": "Abonnement",
            "ja": "サブスク", "id": "Langganan", "tr": "Abonelik"],
        "Add Link": [
            "ru": "Добавить ссылку", "zh": "添加链接", "es": "Añadir enlace", "hi": "लिंक जोड़ें",
            "ar": "إضافة رابط", "fr": "Ajouter un lien", "pt": "Adicionar link", "de": "Link hinzufügen",
            "ja": "リンク追加", "id": "Tambah tautan", "tr": "Bağlantı ekle"],
        "Refresh": [
            "ru": "Обновить", "zh": "刷新", "es": "Actualizar", "hi": "ताज़ा करें",
            "ar": "تحديث", "fr": "Actualiser", "pt": "Atualizar", "de": "Aktualisieren",
            "ja": "更新", "id": "Segarkan", "tr": "Yenile"],
        "Test Ping": [
            "ru": "Тест пинга", "zh": "测试延迟", "es": "Probar ping", "hi": "पिंग जांचें",
            "ar": "اختبار البينغ", "fr": "Tester le ping", "pt": "Testar ping", "de": "Ping testen",
            "ja": "Ping測定", "id": "Uji ping", "tr": "Ping testi"],
        "Log": [
            "ru": "Лог", "zh": "日志", "es": "Registro", "hi": "लॉग",
            "ar": "السجل", "fr": "Journal", "pt": "Registro", "de": "Protokoll",
            "ja": "ログ", "id": "Log", "tr": "Günlük"],
        "Settings": [
            "ru": "Настройки", "zh": "设置", "es": "Ajustes", "hi": "सेटिंग्स",
            "ar": "الإعدادات", "fr": "Réglages", "pt": "Configurações", "de": "Einstellungen",
            "ja": "設定", "id": "Pengaturan", "tr": "Ayarlar"],

        // MARK: Search / filter
        "Search servers…": [
            "ru": "Поиск серверов…", "zh": "搜索服务器…", "es": "Buscar servidores…",
            "hi": "सर्वर खोजें…", "ar": "البحث عن خوادم…", "fr": "Rechercher des serveurs…",
            "pt": "Buscar servidores…", "de": "Server suchen…", "ja": "サーバー検索…",
            "id": "Cari server…", "tr": "Sunucu ara…"],
        "Alive": [
            "ru": "Живые", "zh": "在线", "es": "Activos", "hi": "सक्रिय",
            "ar": "نشط", "fr": "Actifs", "pt": "Ativos", "de": "Aktiv",
            "ja": "応答", "id": "Aktif", "tr": "Aktif"],
        "By ping": [
            "ru": "По пингу", "zh": "按延迟", "es": "Por ping", "hi": "पिंग अनुसार",
            "ar": "حسب البينغ", "fr": "Par ping", "pt": "Por ping", "de": "Nach Ping",
            "ja": "Ping順", "id": "Per ping", "tr": "Ping'e göre"],

        // MARK: Empty state
        "No servers yet": [
            "ru": "Пока нет серверов", "zh": "暂无服务器", "es": "Aún no hay servidores",
            "hi": "अभी कोई सर्वर नहीं", "ar": "لا توجد خوادم بعد", "fr": "Aucun serveur",
            "pt": "Nenhum servidor ainda", "de": "Noch keine Server", "ja": "サーバーがありません",
            "id": "Belum ada server", "tr": "Henüz sunucu yok"],
        "Add a subscription or paste a link to get started.": [
            "ru": "Добавьте подписку или вставьте ссылку, чтобы начать.",
            "zh": "添加订阅或粘贴链接以开始。", "es": "Añade una suscripción o pega un enlace para empezar.",
            "hi": "शुरू करने के लिए सदस्यता जोड़ें या लिंक पेस्ट करें।",
            "ar": "أضف اشتراكًا أو ألصق رابطًا للبدء.", "fr": "Ajoutez un abonnement ou collez un lien pour commencer.",
            "pt": "Adicione uma assinatura ou cole um link para começar.",
            "de": "Abonnement hinzufügen oder Link einfügen, um zu starten.",
            "ja": "サブスクを追加するかリンクを貼り付けて開始します。",
            "id": "Tambahkan langganan atau tempel tautan untuk memulai.",
            "tr": "Başlamak için abonelik ekleyin veya bağlantı yapıştırın."],
        "Add Subscription": [
            "ru": "Добавить подписку", "zh": "添加订阅", "es": "Añadir suscripción",
            "hi": "सदस्यता जोड़ें", "ar": "إضافة اشتراك", "fr": "Ajouter un abonnement",
            "pt": "Adicionar assinatura", "de": "Abonnement hinzufügen", "ja": "サブスク追加",
            "id": "Tambah langganan", "tr": "Abonelik ekle"],
        "Paste Link": [
            "ru": "Вставить ссылку", "zh": "粘贴链接", "es": "Pegar enlace",
            "hi": "लिंक पेस्ट करें", "ar": "لصق الرابط", "fr": "Coller le lien",
            "pt": "Colar link", "de": "Link einfügen", "ja": "リンクを貼付",
            "id": "Tempel tautan", "tr": "Bağlantı yapıştır"],

        // MARK: Server group menu
        "Test ping": [
            "ru": "Тест пинга", "zh": "测试延迟", "es": "Probar ping", "hi": "पिंग जांचें",
            "ar": "اختبار البينغ", "fr": "Tester le ping", "pt": "Testar ping", "de": "Ping testen",
            "ja": "Ping測定", "id": "Uji ping", "tr": "Ping testi"],
        "Test ping (group)": [
            "ru": "Тест пинга (группа)", "zh": "测试延迟（组）", "es": "Probar ping (grupo)",
            "hi": "पिंग जांचें (समूह)", "ar": "اختبار البينغ (مجموعة)", "fr": "Tester le ping (groupe)",
            "pt": "Testar ping (grupo)", "de": "Ping testen (Gruppe)", "ja": "Ping測定（グループ）",
            "id": "Uji ping (grup)", "tr": "Ping testi (grup)"],
        "Refresh now": [
            "ru": "Обновить сейчас", "zh": "立即刷新", "es": "Actualizar ahora",
            "hi": "अभी ताज़ा करें", "ar": "تحديث الآن", "fr": "Actualiser maintenant",
            "pt": "Atualizar agora", "de": "Jetzt aktualisieren", "ja": "今すぐ更新",
            "id": "Segarkan sekarang", "tr": "Şimdi yenile"],
        "Auto-update": [
            "ru": "Автообновление", "zh": "自动更新", "es": "Auto-actualizar",
            "hi": "स्वतः अपडेट", "ar": "تحديث تلقائي", "fr": "Mise à jour auto",
            "pt": "Atualização automática", "de": "Auto-Update", "ja": "自動更新",
            "id": "Pembaruan otomatis", "tr": "Otomatik güncelleme"],
        "Switch here": [
            "ru": "Переключить сюда", "zh": "切换到此", "es": "Cambiar aquí",
            "hi": "यहां स्विच करें", "ar": "التبديل هنا", "fr": "Basculer ici",
            "pt": "Mudar para aqui", "de": "Hierhin wechseln", "ja": "ここに切替",
            "id": "Beralih ke sini", "tr": "Buraya geç"],

        // MARK: Add server sheet
        "Add Server(s)": [
            "ru": "Добавить сервер(ы)", "zh": "添加服务器", "es": "Añadir servidor(es)",
            "hi": "सर्वर जोड़ें", "ar": "إضافة خوادم", "fr": "Ajouter des serveurs",
            "pt": "Adicionar servidor(es)", "de": "Server hinzufügen", "ja": "サーバー追加",
            "id": "Tambah server", "tr": "Sunucu ekle"],
        "Paste one or more links (vless://, vmess://, trojan://, ss://). One per line.": [
            "ru": "Вставьте одну или несколько ссылок (vless://, vmess://, trojan://, ss://). По одной на строку.",
            "zh": "粘贴一个或多个链接（vless://、vmess://、trojan://、ss://），每行一个。",
            "es": "Pega uno o más enlaces (vless://, vmess://, trojan://, ss://). Uno por línea.",
            "hi": "एक या अधिक लिंक पेस्ट करें (vless://, vmess://, trojan://, ss://)। प्रति पंक्ति एक।",
            "ar": "ألصق رابطًا واحدًا أو أكثر (vless://، vmess://، trojan://، ss://). واحد لكل سطر.",
            "fr": "Collez un ou plusieurs liens (vless://, vmess://, trojan://, ss://). Un par ligne.",
            "pt": "Cole um ou mais links (vless://, vmess://, trojan://, ss://). Um por linha.",
            "de": "Einen oder mehrere Links einfügen (vless://, vmess://, trojan://, ss://). Einer pro Zeile.",
            "ja": "1つ以上のリンクを貼り付け（vless://、vmess://、trojan://、ss://）。1行に1つ。",
            "id": "Tempel satu atau beberapa tautan (vless://, vmess://, trojan://, ss://). Satu per baris.",
            "tr": "Bir veya daha fazla bağlantı yapıştırın (vless://, vmess://, trojan://, ss://). Her satıra bir tane."],
        "No valid links found. Check the format.": [
            "ru": "Не найдено корректных ссылок. Проверьте формат.",
            "zh": "未找到有效链接。请检查格式。", "es": "No se encontraron enlaces válidos. Comprueba el formato.",
            "hi": "कोई मान्य लिंक नहीं मिला। प्रारूप जांचें।", "ar": "لم يتم العثور على روابط صالحة. تحقق من التنسيق.",
            "fr": "Aucun lien valide trouvé. Vérifiez le format.", "pt": "Nenhum link válido encontrado. Verifique o formato.",
            "de": "Keine gültigen Links gefunden. Format prüfen.", "ja": "有効なリンクがありません。形式を確認してください。",
            "id": "Tidak ada tautan valid. Periksa formatnya.", "tr": "Geçerli bağlantı bulunamadı. Biçimi kontrol edin."],
        "Each subscription becomes its own profile group.": [
            "ru": "Каждая подписка становится отдельной группой профиля.",
            "zh": "每个订阅成为独立的配置组。", "es": "Cada suscripción se convierte en su propio grupo.",
            "hi": "प्रत्येक सदस्यता अपना प्रोफ़ाइल समूह बनती है।", "ar": "يصبح كل اشتراك مجموعة ملف خاصة به.",
            "fr": "Chaque abonnement devient son propre groupe.", "pt": "Cada assinatura vira seu próprio grupo.",
            "de": "Jedes Abonnement wird zu einer eigenen Gruppe.", "ja": "各サブスクは独自のプロファイルグループになります。",
            "id": "Setiap langganan menjadi grup profilnya sendiri.", "tr": "Her abonelik kendi profil grubu olur."],
        "Name (optional)": [
            "ru": "Название (необязательно)", "zh": "名称（可选）", "es": "Nombre (opcional)",
            "hi": "नाम (वैकल्पिक)", "ar": "الاسم (اختياري)", "fr": "Nom (facultatif)",
            "pt": "Nome (opcional)", "de": "Name (optional)", "ja": "名前（任意）",
            "id": "Nama (opsional)", "tr": "Ad (isteğe bağlı)"],

        // MARK: Settings sections
        "Tunnel": [
            "ru": "Туннель", "zh": "隧道", "es": "Túnel", "hi": "टनल",
            "ar": "النفق", "fr": "Tunnel", "pt": "Túnel", "de": "Tunnel",
            "ja": "トンネル", "id": "Terowongan", "tr": "Tünel"],
        "Mode": [
            "ru": "Режим", "zh": "模式", "es": "Modo", "hi": "मोड",
            "ar": "الوضع", "fr": "Mode", "pt": "Modo", "de": "Modus",
            "ja": "モード", "id": "Mode", "tr": "Mod"],
        "Appearance": [
            "ru": "Оформление", "zh": "外观", "es": "Apariencia", "hi": "रूप",
            "ar": "المظهر", "fr": "Apparence", "pt": "Aparência", "de": "Erscheinungsbild",
            "ja": "外観", "id": "Tampilan", "tr": "Görünüm"],
        "Theme": [
            "ru": "Тема", "zh": "主题", "es": "Tema", "hi": "थीम",
            "ar": "السمة", "fr": "Thème", "pt": "Tema", "de": "Design",
            "ja": "テーマ", "id": "Tema", "tr": "Tema"],
        "Language": [
            "ru": "Язык", "zh": "语言", "es": "Idioma", "hi": "भाषा",
            "ar": "اللغة", "fr": "Langue", "pt": "Idioma", "de": "Sprache",
            "ja": "言語", "id": "Bahasa", "tr": "Dil"],
        "Subscriptions": [
            "ru": "Подписки", "zh": "订阅", "es": "Suscripciones", "hi": "सदस्यताएं",
            "ar": "الاشتراكات", "fr": "Abonnements", "pt": "Assinaturas", "de": "Abonnements",
            "ja": "サブスク", "id": "Langganan", "tr": "Abonelikler"],
        "Auto-update subscriptions": [
            "ru": "Автообновление подписок", "zh": "自动更新订阅", "es": "Auto-actualizar suscripciones",
            "hi": "सदस्यताएं स्वतः अपडेट करें", "ar": "تحديث الاشتراكات تلقائيًا", "fr": "Mettre à jour les abonnements auto",
            "pt": "Atualizar assinaturas automaticamente", "de": "Abos automatisch aktualisieren",
            "ja": "サブスクを自動更新", "id": "Perbarui langganan otomatis", "tr": "Abonelikleri otomatik güncelle"],
        "Send HWID with subscription requests": [
            "ru": "Отправлять HWID с запросами подписки", "zh": "订阅请求附带 HWID", "es": "Enviar HWID con solicitudes de suscripción",
            "hi": "सदस्यता अनुरोधों के साथ HWID भेजें", "ar": "إرسال HWID مع طلبات الاشتراك", "fr": "Envoyer le HWID avec les demandes d'abonnement",
            "pt": "Enviar HWID com solicitações de assinatura", "de": "HWID mit Abo-Anfragen senden",
            "ja": "サブスクリクエストにHWIDを送信", "id": "Kirim HWID dengan permintaan langganan", "tr": "Abonelik istekleriyle HWID gönder"],
        "Identifies this device to providers that require it.": [
            "ru": "Идентифицирует устройство для провайдеров, которым это требуется.", "zh": "为需要识别的提供商标识此设备。", "es": "Identifica este dispositivo para los proveedores que lo requieren.",
            "hi": "इस डिवाइस को आवश्यक प्रदाताओं के लिए पहचानता है।", "ar": "يحدد هذا الجهاز للمزودين الذين يتطلبون ذلك.", "fr": "Identifie cet appareil auprès des fournisseurs qui l'exigent.",
            "pt": "Identifica este dispositivo para provedores que exigem.", "de": "Identifiziert dieses Gerät bei Anbietern, die dies verlangen.",
            "ja": "必要なプロバイダーにこのデバイスを識別させます。", "id": "Mengidentifikasi perangkat ini untuk penyedia yang memerlukannya.", "tr": "Bu cihazı gerektiren sağlayıcılar için tanımlar."],
        "Window": [
            "ru": "Окно", "zh": "窗口", "es": "Ventana", "hi": "विंडो",
            "ar": "النافذة", "fr": "Fenêtre", "pt": "Janela", "de": "Fenster",
            "ja": "ウィンドウ", "id": "Jendela", "tr": "Pencere"],
        "Close button hides to menu bar": [
            "ru": "Кнопка закрытия сворачивает в меню-бар",
            "zh": "关闭按钮隐藏到菜单栏", "es": "El botón cerrar oculta en la barra de menús",
            "hi": "बंद बटन मेन्यू बार में छुपाता है", "ar": "زر الإغلاق يخفي إلى شريط القوائم",
            "fr": "Le bouton fermer masque dans la barre de menus", "pt": "Botão fechar oculta na barra de menus",
            "de": "Schließen-Knopf blendet in Menüleiste aus", "ja": "閉じるボタンでメニューバーに格納",
            "id": "Tombol tutup sembunyi ke bilah menu", "tr": "Kapat düğmesi menü çubuğuna gizler"],
        "SOCKS port": [
            "ru": "Порт SOCKS", "zh": "SOCKS 端口", "es": "Puerto SOCKS", "hi": "SOCKS पोर्ट",
            "ar": "منفذ SOCKS", "fr": "Port SOCKS", "pt": "Porta SOCKS", "de": "SOCKS-Port",
            "ja": "SOCKSポート", "id": "Port SOCKS", "tr": "SOCKS portu"],
        "HTTP port": [
            "ru": "Порт HTTP", "zh": "HTTP 端口", "es": "Puerto HTTP", "hi": "HTTP पोर्ट",
            "ar": "منفذ HTTP", "fr": "Port HTTP", "pt": "Porta HTTP", "de": "HTTP-Port",
            "ja": "HTTPポート", "id": "Port HTTP", "tr": "HTTP portu"],
        "Log level": [
            "ru": "Уровень логов", "zh": "日志级别", "es": "Nivel de registro", "hi": "लॉग स्तर",
            "ar": "مستوى السجل", "fr": "Niveau de journal", "pt": "Nível de log", "de": "Log-Level",
            "ja": "ログレベル", "id": "Tingkat log", "tr": "Günlük düzeyi"],
        "Auto-connect on launch": [
            "ru": "Автоподключение при запуске", "zh": "启动时自动连接",
            "es": "Conectar al iniciar", "hi": "लॉन्च पर स्वतः कनेक्ट",
            "ar": "اتصال تلقائي عند البدء", "fr": "Connexion auto au démarrage",
            "pt": "Conectar ao iniciar", "de": "Auto-Verbindung beim Start",
            "ja": "起動時に自動接続", "id": "Sambung otomatis saat mulai",
            "tr": "Başlangıçta otomatik bağlan"],
        "Helper installed": [
            "ru": "Хелпер установлен", "zh": "助手已安装", "es": "Asistente instalado",
            "hi": "हेल्पर स्थापित", "ar": "تم تثبيت المساعد", "fr": "Assistant installé",
            "pt": "Auxiliar instalado", "de": "Helfer installiert", "ja": "ヘルパー導入済み",
            "id": "Helper terpasang", "tr": "Yardımcı kuruldu"],
        "Helper not installed": [
            "ru": "Хелпер не установлен", "zh": "助手未安装", "es": "Asistente no instalado",
            "hi": "हेल्पर स्थापित नहीं", "ar": "المساعد غير مثبت", "fr": "Assistant non installé",
            "pt": "Auxiliar não instalado", "de": "Helfer nicht installiert", "ja": "ヘルパー未導入",
            "id": "Helper belum terpasang", "tr": "Yardımcı kurulu değil"],
        "Install": [
            "ru": "Установить", "zh": "安装", "es": "Instalar", "hi": "इंस्टॉल",
            "ar": "تثبيت", "fr": "Installer", "pt": "Instalar", "de": "Installieren",
            "ja": "インストール", "id": "Pasang", "tr": "Kur"],

        // MARK: Menu bar
        "Open Window": [
            "ru": "Открыть окно", "zh": "打开窗口", "es": "Abrir ventana", "hi": "विंडो खोलें",
            "ar": "فتح النافذة", "fr": "Ouvrir la fenêtre", "pt": "Abrir janela", "de": "Fenster öffnen",
            "ja": "ウィンドウを開く", "id": "Buka jendela", "tr": "Pencereyi aç"],
        "Quit Beacon": [
            "ru": "Выйти из Veil", "zh": "退出 Veil", "es": "Salir de Veil", "hi": "Veil छोड़ें",
            "ar": "إنهاء Veil", "fr": "Quitter Veil", "pt": "Sair do Veil", "de": "Veil beenden",
            "ja": "Veilを終了", "id": "Keluar dari Veil", "tr": "Veil'den çık"],

        // MARK: Routing
        "Routing": [
            "ru": "Маршрутизация", "zh": "路由", "es": "Enrutamiento", "hi": "रूटिंग",
            "ar": "التوجيه", "fr": "Routage", "pt": "Roteamento", "de": "Routing",
            "ja": "ルーティング", "id": "Perutean", "tr": "Yönlendirme"],
        "Configure…": [
            "ru": "Настроить…", "zh": "配置…", "es": "Configurar…", "hi": "कॉन्फ़िगर…",
            "ar": "تكوين…", "fr": "Configurer…", "pt": "Configurar…", "de": "Konfigurieren…",
            "ja": "設定…", "id": "Konfigurasi…", "tr": "Yapılandır…"],
        "Preset": [
            "ru": "Пресет", "zh": "预设", "es": "Preajuste", "hi": "प्रीसेट",
            "ar": "إعداد مسبق", "fr": "Préréglage", "pt": "Predefinição", "de": "Voreinstellung",
            "ja": "プリセット", "id": "Praatur", "tr": "Önayar"],
        "Block ads & trackers": [
            "ru": "Блокировать рекламу и трекеры", "zh": "屏蔽广告和追踪器",
            "es": "Bloquear anuncios y rastreadores", "hi": "विज्ञापन और ट्रैकर ब्लॉक करें",
            "ar": "حظر الإعلانات والمتتبعات", "fr": "Bloquer pubs et traqueurs",
            "pt": "Bloquear anúncios e rastreadores", "de": "Werbung & Tracker blockieren",
            "ja": "広告とトラッカーをブロック", "id": "Blokir iklan & pelacak",
            "tr": "Reklam ve izleyicileri engelle"],
        "Rule database": [
            "ru": "База правил", "zh": "规则数据库", "es": "Base de reglas", "hi": "नियम डेटाबेस",
            "ar": "قاعدة القواعد", "fr": "Base de règles", "pt": "Base de regras", "de": "Regeldatenbank",
            "ja": "ルールDB", "id": "Basis aturan", "tr": "Kural veritabanı"],
        "Rule database (geosite / geoip)": [
            "ru": "База правил (geosite / geoip)", "zh": "规则数据库（geosite / geoip）",
            "es": "Base de reglas (geosite / geoip)", "hi": "नियम डेटाबेस (geosite / geoip)",
            "ar": "قاعدة القواعد (geosite / geoip)", "fr": "Base de règles (geosite / geoip)",
            "pt": "Base de regras (geosite / geoip)", "de": "Regeldatenbank (geosite / geoip)",
            "ja": "ルールDB（geosite / geoip）", "id": "Basis aturan (geosite / geoip)",
            "tr": "Kural veritabanı (geosite / geoip)"],
        "Downloading…": [
            "ru": "Загрузка…", "zh": "下载中…", "es": "Descargando…", "hi": "डाउनलोड हो रहा है…",
            "ar": "جارٍ التنزيل…", "fr": "Téléchargement…", "pt": "Baixando…", "de": "Lädt herunter…",
            "ja": "ダウンロード中…", "id": "Mengunduh…", "tr": "İndiriliyor…"],
        "Updated": [
            "ru": "Обновлено", "zh": "已更新", "es": "Actualizado", "hi": "अपडेट किया गया",
            "ar": "تم التحديث", "fr": "Mis à jour", "pt": "Atualizado", "de": "Aktualisiert",
            "ja": "更新済み", "id": "Diperbarui", "tr": "Güncellendi"],
        "Not downloaded": [
            "ru": "Не загружено", "zh": "未下载", "es": "No descargado", "hi": "डाउनलोड नहीं किया",
            "ar": "لم يتم التنزيل", "fr": "Non téléchargé", "pt": "Não baixado", "de": "Nicht heruntergeladen",
            "ja": "未ダウンロード", "id": "Belum diunduh", "tr": "İndirilmedi"],
        "Download": [
            "ru": "Загрузить", "zh": "下载", "es": "Descargar", "hi": "डाउनलोड",
            "ar": "تنزيل", "fr": "Télécharger", "pt": "Baixar", "de": "Herunterladen",
            "ja": "ダウンロード", "id": "Unduh", "tr": "İndir"],
        "Update": [
            "ru": "Обновить", "zh": "更新", "es": "Actualizar", "hi": "अपडेट",
            "ar": "تحديث", "fr": "Mettre à jour", "pt": "Atualizar", "de": "Aktualisieren",
            "ja": "更新", "id": "Perbarui", "tr": "Güncelle"],
        "This preset needs the rule database. Download it to use geosite/geoip rules.": [
            "ru": "Этому пресету нужна база правил. Загрузите её для geosite/geoip.",
            "zh": "此预设需要规则数据库。下载后才能使用 geosite/geoip 规则。",
            "es": "Este preajuste necesita la base de reglas. Descárgala para usar geosite/geoip.",
            "hi": "इस प्रीसेट को नियम डेटाबेस चाहिए। geosite/geoip नियमों के लिए डाउनलोड करें।",
            "ar": "يحتاج هذا الإعداد إلى قاعدة القواعد. نزّلها لاستخدام قواعد geosite/geoip.",
            "fr": "Ce préréglage nécessite la base de règles. Téléchargez-la pour geosite/geoip.",
            "pt": "Esta predefinição precisa da base de regras. Baixe-a para usar geosite/geoip.",
            "de": "Diese Voreinstellung benötigt die Regeldatenbank. Lade sie für geosite/geoip herunter.",
            "ja": "このプリセットにはルールDBが必要です。geosite/geoipルールのためにダウンロードしてください。",
            "id": "Praatur ini membutuhkan basis aturan. Unduh untuk memakai aturan geosite/geoip.",
            "tr": "Bu önayar kural veritabanı gerektirir. geosite/geoip için indirin."],
        "Downloaded from GitHub. geosite matches domains, geoip matches IPs by country.": [
            "ru": "Загружается с GitHub. geosite — домены, geoip — IP по странам.",
            "zh": "从 GitHub 下载。geosite 匹配域名，geoip 按国家匹配 IP。",
            "es": "Descargado de GitHub. geosite coincide con dominios, geoip con IP por país.",
            "hi": "GitHub से डाउनलोड। geosite डोमेन, geoip देश के अनुसार IP मैच करता है।",
            "ar": "يتم التنزيل من GitHub. geosite يطابق النطاقات، geoip يطابق IP حسب الدولة.",
            "fr": "Téléchargé depuis GitHub. geosite correspond aux domaines, geoip aux IP par pays.",
            "pt": "Baixado do GitHub. geosite corresponde a domínios, geoip a IPs por país.",
            "de": "Von GitHub geladen. geosite trifft Domains, geoip trifft IPs nach Land.",
            "ja": "GitHubからダウンロード。geositeはドメイン、geoipは国別IPに一致。",
            "id": "Diunduh dari GitHub. geosite cocok dengan domain, geoip dengan IP per negara.",
            "tr": "GitHub'dan indirilir. geosite alan adlarıyla, geoip ülkeye göre IP'lerle eşleşir."],
        "No custom rules. Add one below.": [
            "ru": "Нет своих правил. Добавьте ниже.", "zh": "没有自定义规则。在下方添加。",
            "es": "Sin reglas personalizadas. Añade una abajo.", "hi": "कोई कस्टम नियम नहीं। नीचे जोड़ें।",
            "ar": "لا توجد قواعد مخصصة. أضف واحدة أدناه.", "fr": "Aucune règle personnalisée. Ajoutez-en une ci-dessous.",
            "pt": "Sem regras personalizadas. Adicione uma abaixo.", "de": "Keine eigenen Regeln. Unten hinzufügen.",
            "ja": "カスタムルールがありません。下に追加してください。", "id": "Tidak ada aturan khusus. Tambah di bawah.",
            "tr": "Özel kural yok. Aşağıdan ekleyin."],
        "Add rule": [
            "ru": "Добавить правило", "zh": "添加规则", "es": "Añadir regla", "hi": "नियम जोड़ें",
            "ar": "إضافة قاعدة", "fr": "Ajouter une règle", "pt": "Adicionar regra", "de": "Regel hinzufügen",
            "ja": "ルールを追加", "id": "Tambah aturan", "tr": "Kural ekle"],
        "Custom rules (top to bottom, first match wins)": [
            "ru": "Свои правила (сверху вниз, срабатывает первое)",
            "zh": "自定义规则（自上而下，首条匹配生效）",
            "es": "Reglas personalizadas (de arriba abajo, gana la primera)",
            "hi": "कस्टम नियम (ऊपर से नीचे, पहला मैच लागू)",
            "ar": "قواعد مخصصة (من الأعلى للأسفل، الأول يفوز)",
            "fr": "Règles personnalisées (de haut en bas, la première gagne)",
            "pt": "Regras personalizadas (de cima para baixo, vence a primeira)",
            "de": "Eigene Regeln (oben nach unten, erste Übereinstimmung gewinnt)",
            "ja": "カスタムルール（上から下へ、最初の一致が有効）",
            "id": "Aturan khusus (atas ke bawah, cocok pertama menang)",
            "tr": "Özel kurallar (yukarıdan aşağıya, ilk eşleşme kazanır)"],
        "Domains: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.": [
            "ru": "Домены: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "zh": "域名：example.com、domain:example.com、geosite:category-ads-all、keyword:google。IP：1.2.3.0/24、geoip:cn、geoip:private。",
            "es": "Dominios: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "hi": "डोमेन: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "ar": "النطاقات: example.com، domain:example.com، geosite:category-ads-all، keyword:google. IP: 1.2.3.0/24، geoip:cn، geoip:private.",
            "fr": "Domaines : example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP : 1.2.3.0/24, geoip:cn, geoip:private.",
            "pt": "Domínios: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "de": "Domains: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "ja": "ドメイン: example.com、domain:example.com、geosite:category-ads-all、keyword:google。IP: 1.2.3.0/24、geoip:cn、geoip:private。",
            "id": "Domain: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "tr": "Alan adları: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private."],
        "Rule name": [
            "ru": "Название правила", "zh": "规则名称", "es": "Nombre de regla", "hi": "नियम नाम",
            "ar": "اسم القاعدة", "fr": "Nom de la règle", "pt": "Nome da regra", "de": "Regelname",
            "ja": "ルール名", "id": "Nama aturan", "tr": "Kural adı"],
        "Domains": [
            "ru": "Домены", "zh": "域名", "es": "Dominios", "hi": "डोमेन",
            "ar": "النطاقات", "fr": "Domaines", "pt": "Domínios", "de": "Domains",
            "ja": "ドメイン", "id": "Domain", "tr": "Alan adları"],
        "IPs / CIDR": [
            "ru": "IP / CIDR", "zh": "IP / CIDR", "es": "IP / CIDR", "hi": "IP / CIDR",
            "ar": "IP / CIDR", "fr": "IP / CIDR", "pt": "IP / CIDR", "de": "IP / CIDR",
            "ja": "IP / CIDR", "id": "IP / CIDR", "tr": "IP / CIDR"],
        "Port": [
            "ru": "Порт", "zh": "端口", "es": "Puerto", "hi": "पोर्ट",
            "ar": "المنفذ", "fr": "Port", "pt": "Porta", "de": "Port",
            "ja": "ポート", "id": "Port", "tr": "Port"],
        "Reconnect to apply routing changes.": [
            "ru": "Переподключитесь, чтобы применить изменения маршрутизации.",
            "zh": "重新连接以应用路由更改。", "es": "Reconecta para aplicar los cambios de enrutamiento.",
            "hi": "रूटिंग परिवर्तन लागू करने के लिए फिर से कनेक्ट करें।", "ar": "أعد الاتصال لتطبيق تغييرات التوجيه.",
            "fr": "Reconnectez-vous pour appliquer les changements de routage.", "pt": "Reconecte para aplicar as alterações de roteamento.",
            "de": "Neu verbinden, um Routing-Änderungen anzuwenden.", "ja": "ルーティングの変更を適用するには再接続してください。",
            "id": "Sambungkan ulang untuk menerapkan perubahan perutean.", "tr": "Yönlendirme değişikliklerini uygulamak için yeniden bağlanın."],

        // MARK: Manual selection / deletion
        "Select": [
            "ru": "Выбрать", "zh": "选择", "es": "Seleccionar", "hi": "चुनें",
            "ar": "تحديد", "fr": "Sélectionner", "pt": "Selecionar", "de": "Auswählen",
            "ja": "選択", "id": "Pilih", "tr": "Seç"],
        "Select All": [
            "ru": "Выбрать все", "zh": "全选", "es": "Seleccionar todo", "hi": "सभी चुनें",
            "ar": "تحديد الكل", "fr": "Tout sélectionner", "pt": "Selecionar tudo", "de": "Alle auswählen",
            "ja": "すべて選択", "id": "Pilih semua", "tr": "Tümünü seç"],
        "Deselect All": [
            "ru": "Снять выбор", "zh": "取消全选", "es": "Deseleccionar todo", "hi": "चयन हटाएं",
            "ar": "إلغاء تحديد الكل", "fr": "Tout désélectionner", "pt": "Desmarcar tudo", "de": "Auswahl aufheben",
            "ja": "選択解除", "id": "Batalkan semua", "tr": "Seçimi kaldır"],
        "Delete Selected": [
            "ru": "Удалить выбранные", "zh": "删除所选", "es": "Eliminar seleccionados",
            "hi": "चयनित हटाएं", "ar": "حذف المحدد", "fr": "Supprimer la sélection",
            "pt": "Excluir selecionados", "de": "Auswahl löschen", "ja": "選択を削除",
            "id": "Hapus terpilih", "tr": "Seçilenleri sil"],
        "Manual": [
            "ru": "Вручную", "zh": "手动", "es": "Manual", "hi": "मैनुअल",
            "ar": "يدوي", "fr": "Manuel", "pt": "Manual", "de": "Manuell",
            "ja": "手動", "id": "Manual", "tr": "Manuel"],
        "System": [
            "ru": "Системный", "zh": "系统", "es": "Sistema", "hi": "सिस्टम",
            "ar": "النظام", "fr": "Système", "pt": "Sistema", "de": "System",
            "ja": "システム", "id": "Sistem", "tr": "Sistem"],
    ]
}
