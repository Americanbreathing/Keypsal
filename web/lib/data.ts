export type Script = {
  id: string;
  name: string;
  status: "online" | "down" | "updating";
  description: string;
};

export const scripts: Script[] = [
  { id: "script-01", name: "Aura", status: "online", description: "Advanced combat assistance script for superior tracking." },
  { id: "script-02", name: "Chrono", status: "updating", description: "Time manipulation and speed enhancements." },
  { id: "script-03", name: "Vision", status: "online", description: "Full-map ESP and wallhack capabilities." },
  { id: "script-04", name: "Guardian", status: "down", description: "Protective script with auto-defense and damage mitigation." },
  { id: "script-05", name: "Reaper", status: "online", description: "High-damage output script for aggressive playstyles." },
];

export type UserScript = {
  id: string;
  name: string;
  version: string;
  purchaseDate: string;
};

export const userScripts: UserScript[] = [
    { id: "script-01", name: "Aura", version: "2.5.1", purchaseDate: "2024-05-20" },
    { id: "script-03", name: "Vision", version: "1.8.0", purchaseDate: "2024-04-12" },
    { id: "script-05", name: "Reaper", version: "3.0.0", purchaseDate: "2024-06-01" },
];

export type CommunityConfig = {
    id: string;
    author: string;
    scriptName: string;
    title: string;
    description: string;
    upvotes: number;
    createdAt: string;
    configData: string;
};

export const communityConfigs: CommunityConfig[] = [
    { id: "cfg-01", author: "Ghost", scriptName: "Aura", title: "Passive-Aggressive Aura Setup", description: "Great for flanking and holding positions without being too obvious. Low-medium FOV.", upvotes: 128, createdAt: "2024-06-10", configData: `{"sensitivity": 1.2, "fov": 90, "smoothing": 0.8}` },
    { id: "cfg-02", author: "Viper", scriptName: "Reaper", title: "Max DPS Reaper Config", description: "Full send. This config is for wiping squads. High risk, high reward.", upvotes: 256, createdAt: "2024-06-09", configData: `{"damage_multiplier": 1.5, "fire_rate": "max", "recoil_control": 0.2}` },
    { id: "cfg-03", author: "Shadow", scriptName: "Vision", title: "Tactical Vision for Snipers", description: "Only highlights enemies in direct line of sight, less screen clutter.", upvotes: 97, createdAt: "2024-06-11", configData: `{"render_distance": 500, "show_team": false, "render_mode": "los"}` },
    { id: "cfg-04", author: "Rogue", scriptName: "Aura", title: "Legit Looking Aim Assist", description: "Perfect for streaming or recording, very hard to detect. Feels like controller aim assist.", upvotes: 153, createdAt: "2024-06-08", configData: `{"sensitivity": 0.8, "fov": 60, "smoothing": 1.5}` },

];

export const hwidResets = {
    used: 1,
    total: 3,
};
