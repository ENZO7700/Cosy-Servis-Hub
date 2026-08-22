import type { SectionPatch } from "./types";
import { validatePatches } from "./patch";

export type SalonOsJetEngineMappings = {
  hero: { collection: "sections"; type: "hero"; id: number };
  serviceList: { collection: "sections"; type: "pricing"; id: number };
  photoGallery: { collection: "sections"; type: "gallery"; id: number };
  bookingCta: { collection: "sections"; type: "cta"; id: number };
  pageId: number;
  seoId?: number;
};

export type SalonOsContent = {
  businessName: string;
  tagline: string;
  heroImageId?: number;
  services: Array<{ name: string; price: string; duration?: string }>;
  galleryImageIds: number[];
  bookingUrl: string;
  bookingLabel?: string;
  seo?: { title?: string; description?: string };
};

/**
 * JetEngine CCT mapping for the flagship PAPI HAIR DESIGN salon.
 * IDs remain configurable because each WordPress site can have its own CCT
 * records; the field names are the shared SALONOS contract.
 */
export const PAPI_HAIR_DESIGN_JETENGINE_MAPPINGS: SalonOsJetEngineMappings = {
  pageId: 4,
  hero: { collection: "sections", type: "hero", id: 5 },
  serviceList: { collection: "sections", type: "pricing", id: 6 },
  photoGallery: { collection: "sections", type: "gallery", id: 7 },
  bookingCta: { collection: "sections", type: "cta", id: 9 },
  seoId: 8,
};

export function mapSalonOsContentToJetEnginePatches(
  content: SalonOsContent,
  mappings: SalonOsJetEngineMappings = PAPI_HAIR_DESIGN_JETENGINE_MAPPINGS,
): SectionPatch[] {
  const services = content.services
    .map((service) =>
      [service.name, service.price, service.duration].filter(Boolean).join(" · "),
    )
    .join("\n");
  const gallery = content.galleryImageIds.join(",");
  const patches: SectionPatch[] = [
    {
      op: "update",
      collection: mappings.hero.collection,
      id: mappings.hero.id,
      pageId: mappings.pageId,
      type: mappings.hero.type,
      fields: {
        nadpis: content.businessName,
        text: content.tagline,
        ...(content.heroImageId ? { image_id: content.heroImageId } : {}),
      },
    },
    {
      op: "update",
      collection: mappings.serviceList.collection,
      id: mappings.serviceList.id,
      pageId: mappings.pageId,
      type: mappings.serviceList.type,
      fields: { nadpis: "Služby a cenník", text: services },
    },
    {
      op: "update",
      collection: mappings.photoGallery.collection,
      id: mappings.photoGallery.id,
      pageId: mappings.pageId,
      type: mappings.photoGallery.type,
      fields: { nadpis: "Galéria", text: gallery },
    },
    {
      op: "update",
      collection: mappings.bookingCta.collection,
      id: mappings.bookingCta.id,
      pageId: mappings.pageId,
      type: mappings.bookingCta.type,
      fields: {
        text: "Rezervuj si svoj termín u PAPI HAIR DESIGN.",
        cta_name: content.bookingLabel ?? "Rezervovať termín",
        cta_link: content.bookingUrl,
      },
    },
  ];

  if (mappings.seoId && content.seo) {
    patches.push({
      op: "update",
      collection: "seo",
      id: mappings.seoId,
      pageId: mappings.pageId,
      fields: {
        ...(content.seo.title ? { meta_title: content.seo.title } : {}),
        ...(content.seo.description
          ? { meta_description: content.seo.description }
          : {}),
      },
    });
  }

  return validatePatches(patches).length === 0 ? patches : [];
}