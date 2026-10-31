document.addEventListener("DOMContentLoaded", () => {
    const bell = document.getElementById("notificationBell");
    const dropdown = document.getElementById("notificationDropdown");
    const badge = document.getElementById("notificationBadge");
    const list = document.getElementById("notificationList");
    const close = document.getElementById("notificationClose");
    const refresh = document.getElementById("notificationRefresh");

    if (!bell || !dropdown || !badge || !list) return;

    const token = document.querySelector(
        'input[name="__RequestVerificationToken"]'
    )?.value;

    function createTextElement(tag, className, value) {
        const element = document.createElement(tag);
        element.className = className;
        element.textContent = value ?? "";
        return element;
    }

    function renderNotifications(items) {
        list.replaceChildren();

        if (!items.length) {
            list.appendChild(
                createTextElement(
                    "div",
                    "sl-notification-empty",
                    "Bạn chưa có thông báo nào."
                )
            );
            return;
        }

        items.forEach(item => {
            const id = item.maThongBao ?? item.MaThongBao;
            const title = item.tieuDe ?? item.TieuDe ?? "Thông báo";
            const content = item.noiDung ?? item.NoiDung ?? "";
            const read = item.daDoc ?? item.DaDoc ?? false;
            const date = item.thoiGianGui ?? item.ThoiGianGui;

            const row = document.createElement("div");
            row.className =
                "sl-notification-item" + (read ? "" : " unread");

            const icon = createTextElement(
                "span",
                "sl-notification-icon",
                "🔔"
            );

            const body = document.createElement("div");
            body.className = "sl-notification-body";

            body.appendChild(
                createTextElement("strong", "", title)
            );

            body.appendChild(
                createTextElement("p", "", content)
            );

            if (date) {
                const parsedDate = new Date(date);

                if (!Number.isNaN(parsedDate.getTime())) {
                    body.appendChild(
                        createTextElement(
                            "small",
                            "",
                            parsedDate.toLocaleString("vi-VN")
                        )
                    );
                }
            }

            row.append(icon, body);

            if (!read && id) {
                const button = createTextElement(
                    "button",
                    "sl-notification-read",
                    "Đã đọc"
                );

                button.type = "button";

                button.addEventListener("click", async () => {
                    if (!token) return;

                    try {
                        const response = await fetch(
                            `/ThongBao/DanhDauDaDoc/${encodeURIComponent(id)}`,
                            {
                                method: "PUT",
                                headers: {
                                    "RequestVerificationToken": token
                                }
                            }
                        );

                        if (response.ok) {
                            await loadNotifications();
                        }
                    } catch (error) {
                        console.error("Không thể đánh dấu đã đọc", error);
                    }
                });

                row.appendChild(button);
            }

            list.appendChild(row);
        });
    }

    async function loadNotifications() {
        try {
            const response = await fetch(
                "/ThongBao/DanhSach?trang=1&kichThuocTrang=100",
                { cache: "no-store" }
            );

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();

            const items = data.duLieu ?? data.DuLieu ?? [];

            renderNotifications(items);

            const unread = items.filter(
                x => !(x.daDoc ?? x.DaDoc ?? false)
            ).length;

            badge.textContent = unread > 99 ? "99+" : unread;
            badge.hidden = unread === 0;

        } catch (error) {
            console.error("Lỗi tải thông báo:", error);

            list.replaceChildren(
                createTextElement(
                    "div",
                    "sl-notification-empty",
                    "Không thể tải thông báo. Vui lòng thử lại."
                )
            );

            badge.hidden = true;
        }
    }

    function setOpen(open) {
        dropdown.hidden = !open;
        bell.setAttribute("aria-expanded", String(open));

        if (open) loadNotifications();
    }

    bell.addEventListener("click", () => {
        setOpen(dropdown.hidden);
    });

    close?.addEventListener("click", () => {
        setOpen(false);
    });

    refresh?.addEventListener("click", loadNotifications);

    document.addEventListener("click", event => {
        if (!event.target.closest(".sl-notification-wrapper")) {
            setOpen(false);
        }
    });

    document.addEventListener("keydown", event => {
        if (event.key === "Escape") setOpen(false);
    });

    loadNotifications();

    // Kiểm tra thông báo mới mỗi 60 giây.
    setInterval(() => {
        if (!document.hidden) loadNotifications();
    }, 60000);
});