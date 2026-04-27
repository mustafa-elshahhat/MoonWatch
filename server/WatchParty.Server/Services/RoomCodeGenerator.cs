using System.Security.Cryptography;

namespace WatchParty.Server.Services;

/// <summary>
/// Generates cryptographically random room codes 
/// 6 characters, 32-character set: A-Z (minus I,O) + 2-9.
/// Uses System.Security.Cryptography.RandomNumberGenerator (CSPRNG).
/// </summary>
public static class RoomCodeGenerator
{
    /// <summary>
    /// Character set: A-Z minus I,O (24 letters) + 2-9 (8 digits) = 32 characters.
    /// </summary>
    private static readonly char[] CharacterSet =
        "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".ToCharArray();

    private const int CodeLength = 6;
    private const int MaxCollisionRetries = 3;

    /// <summary>
    /// Generate a room code. Retries up to 3 times if collision is detected.
    /// </summary>
    /// <param name="codeExists">Predicate that returns true if the code already exists in the registry.</param>
    /// <returns>A unique 6-character room code.</returns>
    /// <exception cref="InvalidOperationException">Thrown if all retries fail due to collisions.</exception>
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
            // Unbiased modular selection: 256 / 32 = 8 (no bias since 32 divides 256 evenly)
            code[i] = CharacterSet[randomBytes[i] % CharacterSet.Length];
        }

        return new string(code);
    }
}
