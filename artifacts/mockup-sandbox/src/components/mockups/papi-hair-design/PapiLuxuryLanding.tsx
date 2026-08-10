import { useRef, useState } from "react";
import { ArrowDown, ArrowUpRight, Check, Clock3 } from "lucide-react";
import "./_group.css";

const services = [
  { id: "fade", name: "Fade", desc: "Precízny prechod, textúra a styling s podpisom PAPI.", price: "28 €", time: "45 min" },
  { id: "beard", name: "Beard Trim", desc: "Hot towel rituál, kontúry a finish pre charakteristickú bradu.", price: "18 €", time: "30 min" },
  { id: "vip", name: "VIP Combo", desc: "Fade + Beard Trim. Kompletný look pre dôležité momenty.", price: "42 €", time: "75 min", badge: "Najžiadanejšie" },
];
const slots = ["09:00", "10:30", "13:00", "14:30", "16:00", "17:30"];

export function PapiLuxuryLanding() {
  const bookingRef = useRef<HTMLDivElement>(null);
  const [service, setService] = useState("vip");
  const [slot, setSlot] = useState("");
  const scrollBooking = () => { bookingRef.current?.scrollIntoView({ behavior: "smooth", block: "center" }); };
  const selected = services.find((item) => item.id === service)!;
  return (
    <main className="papi-page">
      <div className="papi-wrap">
        <nav className="papi-nav" aria-label="Main navigation">
          <div className="papi-logo">PAPI <span>HAIR DESIGN</span></div>
          <div className="papi-navlinks"><button onClick={() => document.getElementById("story")?.scrollIntoView({ behavior: "smooth" })}>The story</button><button onClick={() => document.getElementById("services")?.scrollIntoView({ behavior: "smooth" })}>Services</button><button onClick={scrollBooking}>Booking</button></div>
          <button className="papi-ghost papi-kicker" onClick={scrollBooking}>Košice / SK</button>
        </nav>
        <section className="papi-hero">
          <div className="papi-hero-copy">
            <div className="papi-kicker">Gold Haircare Ambassador Salon · Košice</div>
            <h1>Najlepší Fade v Košiciach. <em>Rezervuj si termín online</em> bez telefonovania.</h1>
            <p className="papi-lede">Privátny atelier pre mužov, ktorí nechcú kompromis. Svetová technika, pokojný priestor a čas vyhradený iba pre vás.</p>
            <div className="papi-actions"><button className="papi-primary" onClick={scrollBooking}>Book Appointment <ArrowUpRight size={14} /></button><button className="papi-secondary" onClick={() => document.getElementById("story")?.scrollIntoView({ behavior: "smooth" })}>Discover the atelier <ArrowDown size={14} /></button></div>
          </div>
          <div className="papi-hero-photo" role="img" aria-label="Fresh fade and sculpted beard by PAPI Hair Design"><span className="papi-photo-label">The PAPI signature / 01</span></div>
        </section>
        <section id="story" className="papi-story">
          <div><div className="papi-kicker">01 — The origin</div><h2>From Streets to <em>World Stages</em> — The Story of Róbert Papcun</h2><div className="papi-mark">“</div></div>
          <div className="papi-story-copy"><p>Róbert Papcun vyrastal medzi ulicami Košíc a dnes tvorí looky pre ľudí, ktorí sa pohybujú na svetových pódiách. Jeho remeslo stojí na pozorovaní, disciplíne a milimetroch, ktoré si všimnete až vtedy, keď všetko sedí.</p><p>PAPI nie je rýchla zastávka. Je to 45 minút bez ruchu, bez čakania, bez telefonovania. Len vy, zrkadlo a ruky, ktoré vedia, kam smerovať každý detail.</p></div>
        </section>
        <section id="services" className="papi-services">
          <div className="papi-heading"><div><div className="papi-kicker">02 — The menu</div><h2>Choose your signature.</h2></div><p>Každá návšteva začína krátkou konzultáciou. Vyberte si rituál, zvyšok nechajte na nás.</p></div>
          <div className="papi-service-grid">{services.map((item) => <button key={item.id} className={`papi-service ${service === item.id ? "selected" : ""}`} onClick={() => { setService(item.id); scrollBooking(); }} aria-pressed={service === item.id}><span className="papi-kicker">0{services.indexOf(item) + 1}</span>{item.badge && <span className="papi-badge">{item.badge}</span>}<h3>{item.name}</h3><p>{item.desc}</p><strong className="papi-price">{item.price}</strong><span className="papi-duration">{item.time}</span></button>)}</div>
        </section>
        <section ref={bookingRef} className="papi-booking" aria-label="Appointment booking">
          <div className="papi-booking-intro"><div className="papi-kicker">03 — Your private appointment</div><h2>Good hair.<br /><em>Clear mind.</em></h2><p>Vyberte službu a čas. Potvrdenie vám príde okamžite — bez telefonátu, bez čakania.</p></div>
          <div className="papi-widget"><div className="papi-widget-top"><div><div className="papi-kicker">AI booking concierge</div><div className="papi-widget-title">Reserve your chair</div></div><div className="papi-status">● Live availability</div></div><div className="papi-row-label">Selected service</div><div className="papi-mini-grid">{services.map((item) => <button className={`papi-slot ${service === item.id ? "active" : ""}`} key={item.id} onClick={() => setService(item.id)}>{item.name}</button>)}</div><div className="papi-row-label">Thursday, 24 October</div><div className="papi-mini-grid">{slots.map((item) => <button className={`papi-slot ${slot === item ? "active" : ""}`} key={item} onClick={() => setSlot(item)}><Clock3 size={12} style={{ display: "inline", marginRight: 5 }} />{item}</button>)}</div><button className="papi-primary papi-confirm" disabled={!slot} onClick={() => alert(`Termín ${selected.name} o ${slot} je pripravený na potvrdenie.`)}>{slot ? <><Check size={14} /> Continue with {selected.name}</> : "Select a time to continue"}</button></div>
        </section>
        <footer className="papi-footer"><span><strong>PAPI HAIR DESIGN</strong> · Hlavná 72, Košice</span><span>World stage grooming, local address.</span></footer>
      </div>
    </main>
  );
}