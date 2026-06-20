using System.Security.Cryptography;

namespace WatchParty.Server.Services;






public static class RoomCodeGenerator
{
    
    
    
    private static readonly char[] CharacterSet =
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".ToCharArray();

    private const int CodeLength = 6;
    // With a 32^6 (~1.07B) keyspace, collisions are vanishingly rare; a few
    // extra retries cost nothing and avoid a spurious 503 under high room churn.
    private const int MaxCollisionRetries = 8;

    
    
    
    
    
    
    public static string Generate(Func<string, bool> codeExists)
    {
        for (int attempt = 0; attempt < MaxCollisionRetries; attempt++)
        {
            var code = GenerateRandom();
            if (!codeExists(code))
                return code;
        }

        throw new InvalidOperationException(
            $"Failed to generate a unique room code after {MaxCollisionRetries} attempts.");
    }

    private static string GenerateRandom()
    {
        Span<char> code = stackalloc char[CodeLength];
        Span<byte> randomBytes = stackalloc byte[CodeLength];
        RandomNumberGenerator.Fill(randomBytes);

        for (int i = 0; i < CodeLength; i++)
        {
            
            code[i] = CharacterSet[randomBytes[i] % CharacterSet.Length];
        }

        return new string(code);
    }
}
