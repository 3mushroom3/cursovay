import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Система предложений ДГТУ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Оставляйте инициативы, голосуйте за важные идеи и отслеживайте статус их реализации.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const _FeatureTile(
                icon: Icons.add_circle_outline,
                title: 'Создание предложений',
                subtitle: 'Студенты добавляют идеи с фото и деталями.',
              ),
              const _FeatureTile(
                icon: Icons.rule_folder_outlined,
                title: 'Роли и модерация',
                subtitle: 'Преподаватели и администраторы управляют статусами.',
              ),
              const _FeatureTile(
                icon: Icons.insights_outlined,
                title: 'Статистика и аналитика',
                subtitle: 'Фильтры и метрики по предложениям.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Text('Продолжить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
