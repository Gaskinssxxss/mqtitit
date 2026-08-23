from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "doc" / "figures"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


F_TITLE = font(32, True)
F_HEAD = font(22, True)
F_TEXT = font(19)
F_SMALL = font(16)


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont, max_width: int) -> list[str]:
    lines: list[str] = []
    for para in text.split("\n"):
        words = para.split()
        cur = ""
        for word in words:
            cand = word if not cur else f"{cur} {word}"
            if draw.textbbox((0, 0), cand, font=fnt)[2] <= max_width:
                cur = cand
            else:
                if cur:
                    lines.append(cur)
                cur = word
        if cur:
            lines.append(cur)
    return lines


def box(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], title: str, body: str, fill: str = "#F4F8FB") -> None:
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=22, fill=fill, outline="#214D73", width=3)
    y = y1 + 14
    for title_line in title.splitlines():
        draw.text((x1 + 18, y), title_line, font=F_HEAD, fill="#0B2540")
        y += 28
    y += 10
    for line in wrap(draw, body, F_TEXT, x2 - x1 - 36):
        draw.text((x1 + 18, y), line, font=F_TEXT, fill="#1F2933")
        y += 26


def arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], label: str = "") -> None:
    draw.line([start, end], fill="#0B5CAD", width=5)
    sx, sy = start
    ex, ey = end
    if abs(ex - sx) >= abs(ey - sy):
        sign = 1 if ex > sx else -1
        pts = [(ex, ey), (ex - sign * 18, ey - 10), (ex - sign * 18, ey + 10)]
    else:
        sign = 1 if ey > sy else -1
        pts = [(ex, ey), (ex - 10, ey - sign * 18), (ex + 10, ey - sign * 18)]
    draw.polygon(pts, fill="#0B5CAD")
    if label:
        mx, my = (sx + ex) // 2, (sy + ey) // 2
        tw = draw.textbbox((0, 0), label, font=F_SMALL)[2]
        draw.rectangle((mx - tw // 2 - 8, my - 16, mx + tw // 2 + 8, my + 10), fill="white")
        draw.text((mx - tw // 2, my - 14), label, font=F_SMALL, fill="#0B2540")


def canvas(title: str, w: int = 1400, h: int = 850) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (w, h), "white")
    draw = ImageDraw.Draw(img)
    draw.text((w // 2, 38), title, font=F_TITLE, fill="#0B2540", anchor="mm")
    draw.line((80, 82, w - 80, 82), fill="#D0D7DE", width=2)
    return img, draw


def fig_mqtt_architecture() -> None:
    img, draw = canvas("Arsitektur Komunikasi MQTT Publish-Subscribe")
    box(draw, (80, 210, 360, 420), "Publisher", "Client/perangkat IoT simulasi mengirim data ke topic MQTT.", "#EAF5FF")
    box(draw, (560, 170, 840, 460), "Broker MQTT", "Pusat komunikasi. Menerima publish dan meneruskan pesan ke subscriber.", "#FFF4DE")
    box(draw, (1040, 210, 1320, 420), "Subscriber", "Client/aplikasi penerima data berlangganan topic MQTT.", "#EAFBEA")
    arrow(draw, (360, 315), (560, 315), "publish")
    arrow(draw, (840, 315), (1040, 315), "forward")
    draw.text((700, 535), "Pada penelitian ini broker MQTT menjadi objek utama yang dianalisis.", font=F_TEXT, fill="#1F2933", anchor="mm")
    img.save(OUT / "gambar_2_1_arsitektur_mqtt.png")


def fig_tcp_syn() -> None:
    img, draw = canvas("TCP Three-Way Handshake dan Titik Serangan SYN Flood")
    box(draw, (80, 170, 360, 350), "Client Normal", "Mengirim SYN, menerima SYN-ACK, lalu membalas ACK.", "#EAF5FF")
    box(draw, (560, 170, 840, 350), "Broker MQTT", "Menerima koneksi TCP sebelum komunikasi MQTT berjalan.", "#FFF4DE")
    box(draw, (1040, 170, 1320, 350), "Attacker", "Mengirim banyak paket SYN ke port 1883.", "#FFECEC")
    arrow(draw, (360, 215), (560, 215), "SYN")
    arrow(draw, (560, 260), (360, 260), "SYN-ACK")
    arrow(draw, (360, 305), (560, 305), "ACK")
    for y in [430, 470, 510, 550, 590]:
        arrow(draw, (1040, y), (840, y), "SYN")
    draw.text((700, 675), "SYN flood menambah jumlah paket SYN menuju broker sehingga proses koneksi dapat terbebani.", font=F_TEXT, fill="#1F2933", anchor="mm")
    img.save(OUT / "gambar_2_2_tcp_syn_flood.png")


def fig_system_architecture() -> None:
    img, draw = canvas("Arsitektur Sistem Pengujian")
    box(draw, (70, 190, 420, 470), "Windows Client", "Menjalankan client MQTT normal.\nOutput: mqtt_client.csv\nMengambil hasil dari server.", "#EAF5FF")
    box(draw, (525, 150, 875, 520), "Ubuntu Server A\nBroker MQTT", "Mosquitto port 1883\ntshark packet capture\nraw_flow extraction\nrate limiting", "#FFF4DE")
    box(draw, (980, 190, 1330, 470), "Ubuntu Server B\nAttacker", "Menjalankan hping3.\nMengirim SYN flood ke broker.\nOutput: attack.log", "#FFECEC")
    arrow(draw, (420, 280), (525, 280), "MQTT normal")
    arrow(draw, (980, 330), (875, 330), "SYN flood")
    arrow(draw, (525, 450), (420, 450), "hasil")
    arrow(draw, (980, 450), (875, 450), "hasil")
    draw.text((700, 610), "Capture dilakukan langsung pada Server A karena Server A adalah tempat broker berjalan dan target serangan.", font=F_TEXT, fill="#1F2933", anchor="mm")
    img.save(OUT / "gambar_3_1_arsitektur_sistem_pengujian.png")


def fig_research_flow() -> None:
    img, draw = canvas("Alur Tahapan Penelitian", 1200, 1250)
    steps = [
        "Menyiapkan lingkungan uji",
        "Menjalankan broker MQTT",
        "Menentukan RUN_ID dan skenario",
        "Menjalankan packet capture di Server A",
        "Menjalankan client MQTT normal",
        "Menjalankan SYN flood jika skenario serangan",
        "Mengumpulkan file hasil eksperimen",
        "Mengekstrak raw_flow.csv",
        "Menganalisis trafik dan performa client",
    ]
    x1, x2 = 330, 870
    y = 120
    prev_bottom = None
    for i, step in enumerate(steps, 1):
        box(draw, (x1, y, x2, y + 85), f"Tahap {i}", step, "#F4F8FB")
        if prev_bottom is not None:
            arrow(draw, ((x1 + x2) // 2, prev_bottom), ((x1 + x2) // 2, y))
        prev_bottom = y + 85
        y += 120
    img.save(OUT / "gambar_3_2_alur_tahapan_penelitian.png")


def fig_scenarios() -> None:
    img, draw = canvas("Alur Skenario Pengujian", 1400, 900)
    box(draw, (80, 190, 400, 440), "Skenario 1\nNormal", "Server A capture.\nWindows client MQTT.\nServer B tidak menyerang.", "#EAFBEA")
    box(draw, (540, 190, 860, 440), "Skenario 2\nSYN Flood", "Server A capture.\nServer B hping3.\nWindows client tetap berjalan.", "#FFECEC")
    box(draw, (1000, 190, 1320, 440), "Skenario 3\nMitigasi", "Server A rate limiting.\nServer B hping3.\nWindows client tetap berjalan.", "#FFF4DE")
    arrow(draw, (400, 315), (540, 315), "bandingkan")
    arrow(draw, (860, 315), (1000, 315), "bandingkan")
    box(draw, (410, 560, 990, 730), "Analisis", "Bandingkan mqtt_client.csv dan raw_flow.csv untuk melihat dampak SYN flood serta efektivitas rate limiting.", "#F4F8FB")
    arrow(draw, (240, 440), (520, 560))
    arrow(draw, (700, 440), (700, 560))
    arrow(draw, (1160, 440), (880, 560))
    img.save(OUT / "gambar_3_3_alur_skenario_pengujian.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fig_mqtt_architecture()
    fig_tcp_syn()
    fig_system_architecture()
    fig_research_flow()
    fig_scenarios()
    for p in sorted(OUT.glob("gambar_*.png")):
        print(p)


if __name__ == "__main__":
    main()
