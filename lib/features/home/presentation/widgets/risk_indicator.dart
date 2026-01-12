import 'package:flutter/material.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class RiskStatusIndicator extends StatelessWidget {
  final RiskData? riskData;
  final VoidCallback? onTap;

  const RiskStatusIndicator({
    super.key,
    this.riskData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (riskData == null) {
      return Container();
    }
    
    final level = riskData!.level;
    final score = riskData!.score;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: riskData!.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: riskData!.color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: riskData!.color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getRiskIcon(level),
                size: 20,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Risk Status: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        level,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: riskData!.color,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  Text(
                    'Score: $score',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  if (riskData!.reasons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        riskData!.reasons.map((r) => r.toUpperCase()).join(', '),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${riskData!.speedKmh.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRiskIcon(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return Icons.warning;
      case 'MEDIUM':
        return Icons.warning_amber;
      case 'NORMAL':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}