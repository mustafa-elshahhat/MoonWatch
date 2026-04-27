using WatchParty.Server.Services;

namespace WatchParty.Tests.Services;




public class RoomCodeGeneratorTests
{
    [Fact]
    public void Generate_ReturnsCode_WithExactly6Characters()
    {
        var code = RoomCodeGenerator.Generate(_ => false);
        Assert.Equal(6, code.Length);
    }

    [Fact]
    public void Generate_ReturnsCode_AllUppercase()
    {
        var code = RoomCodeGenerator.Generate(_ => false);
        Assert.Equal(code, code.ToUpperInvariant());
    }

    [Fact]
    public void Generate_ReturnsCode_NeverContainsAmbiguousCharacters()
    {
        
        var forbidden = new[] { 'I', 'O', '0', '1' };

        for (int i = 0; i < 100; i++)
        {
            var code = RoomCodeGenerator.Generate(_ => false);
            foreach (var c in forbidden)
            {
                Assert.DoesNotContain(c.ToString(), code);
            }
        }
    }

    [Fact]
    public void Generate_ReturnsCode_OnlyContainsValidCharacters()
    {
        var validChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".ToCharArray();

        for (int i = 0; i < 100; i++)
        {
            var code = RoomCodeGenerator.Generate(_ => false);
            foreach (var c in code)
            {
                Assert.Contains(c, validChars);
            }
        }
    }

    [Fact]
    public void Generate_ReturnsStatisticallyRandomCodes()
    {
        
        var codes = new HashSet<string>();
        for (int i = 0; i < 50; i++)
        {
            codes.Add(RoomCodeGenerator.Generate(_ => false));
        }

        
        Assert.True(codes.Count > 40, $"Expected >40 unique codes from 50 generations, got {codes.Count}");
    }

    [Fact]
    public void Generate_RetriesOnCollision()
    {
        int callCount = 0;
        var code = RoomCodeGenerator.Generate(c =>
        {
            callCount++;
            return callCount <= 1; 
        });

        Assert.Equal(6, code.Length);
        Assert.True(callCount >= 2);
    }

    [Fact]
    public void Generate_ThrowsAfterMaxRetries()
    {
        Assert.Throws<InvalidOperationException>(() =>
            RoomCodeGenerator.Generate(_ => true)); 
    }
}
