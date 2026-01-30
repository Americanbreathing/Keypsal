import NextAuth from "next-auth"
import DiscordProvider from "next-auth/providers/discord"

export const authOptions = {
    providers: [
        DiscordProvider({
            clientId: process.env.DISCORD_CLIENT_ID || "",
            clientSecret: process.env.DISCORD_CLIENT_SECRET || "",
            authorization: { params: { scope: 'identify' } },
        }),
    ],
    callbacks: {
        async session({ session, token }: any) {
            if (session.user) {
                session.user.id = token.sub;
            }
            return session;
        },
    },
    pages: {
        signIn: '/',
    },
};

const handler = NextAuth(authOptions);

export { handler as GET, handler as POST };
